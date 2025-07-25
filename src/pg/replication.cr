module PG::Replication
  module Handler
    # This method must be defined in order to tell the `Connection` how much of
    # the WAL has been flushed and applied.
    #
    # ```
    # connection = PG.listen_replication db_url,
    #   handler: MyHandler.new,
    #   publication_name: "my_publication",
    #   slot_name: "my_replication_slot"
    #
    # class MyHandler
    #   include PG::Replication::Handler
    #
    #   @last_wal_byte_flushed = 0i64
    #   @last_wal_byte_applied = 0i64
    #
    #   def received(msg : PG::Replication::XLogData, connection : PG::Replication::Connection, &)
    #     yield
    #     connection.last_wal_byte_flushed = msg.wal_end
    #     if msg.data.is_a? PG::Replication::Commit
    #       connection.last_wal_byte_applied = msg.wal_end
    #     end
    #   end
    # end
    # ```
    abstract def received(data : PG::Replication::XLogData, connection : PG::Replication::Connection, &)

    def received(frame)
    end
  end

  class Connection
    getter handler : Handler
    getter publication_name : String
    getter slot_name : String
    getter last_wal_byte_received = 0i64
    property last_wal_byte_flushed = 0i64
    property last_wal_byte_applied = 0i64
    getter? closed = false

    # :nodoc:
    def initialize(uri : URI | String, @handler, *, @publication_name, @slot_name, blocking : Bool = false)
      if uri.is_a? String
        uri = URI.parse(uri)
      else
        uri = uri.dup
      end
      query_params = uri.query_params
      query_params["replication"] = "database"
      uri.query_params = query_params
      @conn = DB.connect(uri).as(PG::Connection)
      @conn.listen_replication(
        publication_name: publication_name,
        slot_name: slot_name,
        blocking: blocking,
      ) do |frame|
        received frame
      end

      spawn do
        until closed?
          sleep 10.seconds
          begin
            send_keepalive
          rescue ex : IO::Error
            break if closed?
            raise ex
          end
        end
      end
    end

    # :nodoc:
    def received(frame : CopyBoth)
    end

    # :nodoc:
    def received(frame : CopyData)
      received frame.data
    end

    # Handle the `XLogData` message that wraps `WALMessage`s
    def received(data : XLogData)
      @last_wal_byte_received = data.wal_end
      handler.received data, self do
        handler.received data.message
      end
    end

    # :nodoc:
    def received(keepalive : KeepAlive)
      send_keepalive if keepalive.response_expected?
    end

    # This shouldn't ever be received, but it can be represented in memory so we
    # need to include it for completeness.
    def received(response : KeepAliveResponse)
      raise NotImplementedError.new("KeepAliveResponses are intended to be sent, not received")
    end

    def close
      return if closed?
      # We attempt to send off one last keepalive to let the server know where
      # we left off.
      send_keepalive
      @conn.close
    ensure
      @closed = true
    end

    def send_keepalive
      write { send_keepalive! }
    end

    private def send_keepalive! : Nil
      CopyData.new(
        StandbyStatusUpdate.new(
          last_wal_byte_received: last_wal_byte_received,
          last_wal_byte_flushed: last_wal_byte_flushed,
          last_wal_byte_applied: last_wal_byte_applied,
        )
      ).to_io socket

      flush
    end

    private def write(&)
      write_mutex.synchronize { yield }
    end

    private getter write_mutex = Mutex.new

    private def flush
      socket.flush
    end

    private def socket
      @conn.connection.soc
    end
  end

  abstract struct Frame
    def self.from_io(io : IO) : self
      case byte = io.read_byte
      when nil
        raise IO::EOFError.new("Connection was unexpectedly terminated")
      when 'W'
        CopyBoth.new(io)
      when 'd'
        CopyData.new(io)
      else
        raise Error.new("Unexpected byte marker: 0x#{byte.to_s(16)} (#{byte.chr.inspect})")
      end
    end
  end

  struct CopyBoth < Frame
    getter format : Format
    getter column_formats : Array(Int16)

    def initialize(io : IO)
      size = io.read_bytes(Int32, IO::ByteFormat::NetworkEndian)
      sized = IO::Sized.new(io, size - 4)
      @format = Format.new(sized.read_bytes(Int8, IO::ByteFormat::NetworkEndian))
      column_count = sized.read_bytes(Int16, IO::ByteFormat::NetworkEndian)
      @column_formats = Array.new(column_count) do
        sized.read_bytes(Int16, IO::ByteFormat::NetworkEndian)
      end
      sized.close
    end

    enum Format : Int8
      Text   = 0
      Binary = 1
    end
  end

  struct CopyData < Frame
    getter data : XLogData | KeepAlive | KeepAliveResponse

    def initialize(io : IO)
      size = io.read_bytes(Int32, IO::ByteFormat::NetworkEndian)
      case byte = io.read_byte
      when Nil
        raise IO::EOFError.new("Connection was unexpectedly terminated")
      when 'w'
        @data = XLogData.new(io)
      when 'k'
        @data = KeepAlive.new(io)
      else
        raise Error.new("Unexpected CopyData byte marker: 0x#{byte.to_s(16)} (#{byte.chr.inspect})")
      end
    end

    def initialize(@data)
    end

    def to_io(io : IO) : Nil
      buffer = IO::Memory.new
      io << 'd'
      payload = IO::Memory.new.tap { |buf| data.to_io buf }.to_slice
      io.write_bytes payload.bytesize + 4, IO::ByteFormat::NetworkEndian
      io.write payload
    end
  end

  struct XLogData
    getter wal_start : Int64
    getter wal_end : Int64
    getter timestamp : Time
    getter message : WALMessage

    def initialize(io : IO)
      @wal_start = io.read_bytes(Int64, IO::ByteFormat::NetworkEndian)
      @wal_end = io.read_bytes(Int64, IO::ByteFormat::NetworkEndian)
      @timestamp = TimeParser.call(io)
      @message = WALMessage.new(io)
    end

    def to_io(io : IO) : Nil
      raise NotImplementedError.new("XLogData messages are meant to be sent by the server, not received by the client")
    end
  end

  struct KeepAlive
    getter wal_end : Int64
    getter timestamp : Time
    getter? response_expected : Bool

    def initialize(io : IO)
      @wal_end = io.read_bytes(Int64, IO::ByteFormat::NetworkEndian)
      @timestamp = TimeParser.call(io)
      @response_expected = io.read_bytes(Int8, IO::ByteFormat::NetworkEndian) == 1
    end

    def to_io(io : IO) : Nil
      raise NotImplementedError.new("KeepAlives are intended to be received from the server, not sent to it")
    end
  end

  abstract struct KeepAliveResponse
  end

  struct StandbyStatusUpdate < KeepAliveResponse
    getter last_wal_byte_received : Int64
    getter last_wal_byte_flushed : Int64
    getter last_wal_byte_applied : Int64
    getter timestamp : Time
    getter? response_expected : Bool

    def initialize(
      @last_wal_byte_received,
      @last_wal_byte_flushed,
      @last_wal_byte_applied,
      *,
      @timestamp = Time.utc,
      @response_expected = false,
    )
    end

    def to_io(io : IO) : Nil
      io << 'r'
      write io, last_wal_byte_received
      write io, last_wal_byte_flushed
      write io, last_wal_byte_applied
      write io, (@timestamp - Time.utc(2000, 1, 1)).total_microseconds.to_i64
      write io, response_expected? ? 1u8 : 0u8
    end

    private def write(io, value)
      io.write_bytes value, IO::ByteFormat::NetworkEndian
    end
  end

  abstract struct WALMessage
    def self.new(io : IO) : self
      {% if @type != PG::Replication::WALMessage %}
        {% raise "Must implement #{@type}#initialize(io : IO)" %}
      {% end %}

      case byte = io.read_byte
      when Nil
        raise IO::EOFError.new("Connection was unexpectedly terminated")
      when 'B'
        Begin.new(io)
      when 'C'
        Commit.new(io)
      when 'R'
        Relation.new(io)
      when 'I'
        Insert.new(io)
      when 'U'
        Update.new(io)
      when 'D'
        Delete.new(io)
      when 'T'
        Truncate.new(io)
      when 'Y'
        Type.new(io)
      when 'M'
        Message.new(io)
      when 'O'
        Origin.new(io)
      else
        raise Error.new("Unexpected WAL message byte marker: 0x#{byte.to_s(16)} (#{byte.chr.inspect})")
      end
    end

    protected def read(io : IO, int : Int.class)
      io.read_bytes int, IO::ByteFormat::NetworkEndian
    end

    protected def read_string(io : IO) : String
      io.read_line('\0', chomp: true)
    end

    protected def read_bytes(io : IO) : Bytes
      bytes = Bytes.new(read(io, Int32))
      io.read_fully bytes
      bytes
    end

    protected def read_time(io : IO) : Time
      TimeParser.call(io)
    end

    protected def read_tuple_data(io) : TupleData
      column_count = read(io, Int16)
      Array.new(column_count) do
        case byte = io.read_byte
        when Nil
          raise IO::EOFError.new("Connection was unexpectedly terminated")
        when 'n'
          nil
        when 'u'
          UnchangedTOASTValue.new
        when 't'
          read_string(io)
        when 'b'
          read_bytes(io)
        else
          raise Error.new("Unexpected TupleData byte marker: 0x#{byte.to_s(16)} (#{byte.chr.inspect})")
        end
      end
    end

    alias TupleData = Array(UnchangedTOASTValue | Bytes | String | Nil)
    record UnchangedTOASTValue
  end

  struct Begin < WALMessage
    getter final_lsn : Int64
    getter timestamp : Time
    getter transaction_id : Int32

    def initialize(io : IO)
      @final_lsn = read(io, Int64)
      @timestamp = TimeParser.call(io)
      @transaction_id = read(io, Int32)
    end
  end

  struct Message < WALMessage
    # Requires proto_version >= 2
    # getter transaction_id : Int32
    getter flags : Flags
    getter lsn : Int64
    getter prefix : String
    getter content : Bytes

    def initialize(io : IO)
      # @transaction_id = read(io, Int32) # Requires proto_version >= 2
      @flags = Flags.new(read(io, Int8))
      @lsn = read(io, Int64)
      @prefix = read_string(io)
      @content = read_bytes(io)
    end

    @[::Flags]
    enum Flags : Int8
      Transactional
    end
  end

  struct Commit < WALMessage
    getter flags : Int8
    getter begin_lsn : Int64
    getter end_lsn : Int64
    getter timestamp : Time

    def initialize(io : IO)
      @flags = read(io, Int8)
      @begin_lsn = read(io, Int64)
      @end_lsn = read(io, Int64)
      @timestamp = read_time(io)
    end
  end

  struct Origin < WALMessage
    getter lsn : Int64
    getter name : String

    def initialize(io : IO)
      @lsn = read(io, Int64)
      @name = read_string(io)
    end
  end

  struct Relation < WALMessage
    # Requires proto_version >= 2
    # getter transaction_id : Int32
    getter oid : Int32
    getter namespace : String
    getter name : String
    getter replica_identity : Int8
    getter columns : Array(Column)

    def initialize(io : IO)
      # @transaction_id = read(io, Int32)
      @oid = read(io, Int32)
      @namespace = read_string(io)
      @name = read_string(io)
      @replica_identity = read(io, Int8)
      column_count = read(io, Int16)
      @columns = Array.new(column_count) do
        Column.new(
          flags: Flags.new(read(io, Int8)),
          name: read_string(io),
          oid: read(io, Int32),
          type_modifier: read(io, Int32),
        )
      end
    end

    record Column,
      flags : Flags,
      name : String,
      oid : Int32,
      type_modifier : Int32
    @[::Flags]
    enum Flags
      Key = 1
    end
  end

  struct Type < WALMessage
    # getter transaction_id : Int32
    getter oid : Int32
    getter namespace : String
    getter data_type : String

    def initialize(io : IO)
      @oid = read(io, Int32)
      @namespace = read_string(io)
      @data_type = read_string(io)
    end
  end

  struct Insert < WALMessage
    # getter transaction_id : Int32
    getter oid : Int32
    getter tuple_data : TupleData

    def initialize(io : IO)
      # Only included in WAL protocol v2+
      # @transaction_id = read(io, Int32)
      @oid = read(io, Int32)
      # This is an 'N' indicating a new tuple
      io.read_byte
      @tuple_data = read_tuple_data(io)
    end
  end

  struct Update < WALMessage
    getter oid : Int32
    getter key_tuple_data : TupleData?
    getter old_tuple_data : TupleData?
    getter new_tuple_data : TupleData

    def initialize(io : IO)
      @oid = read(io, Int32)
      submessage_type = read(io, UInt8)
      case submessage_type
      when 'K'
        @key_tuple_data = read_tuple_data(io)
      when 'O'
        @old_tuple_data = read_tuple_data(io)
      when 'N'
        new_tuple_data = read_tuple_data(io)
      end

      # If either 'K' or 'O' were specified above, then the next value is our
      # new tuple. Otherwise, that was our new tuple, so we just assign it.
      if new_tuple_data
        @new_tuple_data = new_tuple_data
      else
        case byte = read(io, UInt8)
        when 'N'
          @new_tuple_data = read_tuple_data(io)
        else
          raise Error.new("Expected new TupleData byte marker, got: 0x#{byte.to_s(16)} (#{byte.chr.inspect})")
        end
      end
    end
  end

  struct Delete < WALMessage
    # getter transaction_id : Int32
    getter oid : Int32
    getter key_tuple_data : TupleData?
    getter old_tuple_data : TupleData?

    def initialize(io : IO)
      # @transaction_id = read(io, Int32) # Requires proto_version >= 2
      @oid = read(io, Int32)
      case byte = io.read_byte
      when nil
        raise IO::EOFError.new("Connection was unexpectedly terminated")
      when 'K'
        @key_tuple_data = read_tuple_data(io)
      when 'O'
        @old_tuple_data = read_tuple_data(io)
      else
        raise Error.new("Expected new TupleData byte marker, got: 0x#{byte.to_s(16)} (#{byte.chr.inspect})")
      end
    end
  end

  struct Truncate < WALMessage
    # transaction_id requires proto_version >= 2
    # getter transaction_id : Int32
    getter options : Options
    getter relation_oids : Array(Int32)

    def initialize(io : IO)
      # @transaction_id = read(io, Int32) # Requires proto_version >= 2
      relation_count = read(io, Int32)
      @options = Options.new(read(io, Int8))
      @relation_oids = Array.new(relation_count) do
        read(io, Int32)
      end
    end

    @[Flags]
    enum Options : Int8
      NONE             = 0
      CASCADE          = 1
      RESTART_IDENTITY = 2
    end
  end

  # TODO: Implement the types below in order to support higher `proto_version`s

  # # StreamStart requires proto_version >= 2
  # struct StreamStart < WALMessage
  # end

  # # StreamStop requires proto_version >= 2
  # struct StreamStop < WALMessage
  # end

  # # StreamCommit requires proto_version >= 2
  # struct StreamCommit < WALMessage
  # end

  # # StreamAbort requires proto_version >= 2
  # struct StreamAbort < WALMessage
  # end

  # # BeginPrepare requires proto_version >=3
  # struct BeginPrepare < WALMessage
  # end

  # # Prepare requires proto_version >=3
  # struct Prepare < WALMessage
  # end

  # # CommitPrepared requires proto_version >=3
  # struct CommitPrepared < WALMessage
  # end

  # # RollbackPrepared requires proto_version >=3
  # struct RollbackPrepared < WALMessage
  # end

  # # StreamPrepare requires proto_version >=3
  # struct StreamPrepare < WALMessage
  # end

  private module TimeParser
    extend self

    def call(io : IO) : Time
      call io.read_bytes(Int64, IO::ByteFormat::NetworkEndian)
    end

    def call(microseconds : Int64)
      Time.utc(2000, 1, 1) + microseconds.microseconds
    end
  end
end
