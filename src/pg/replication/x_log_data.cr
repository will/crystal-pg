require "./wal_message"
require "./time_parser"

module PG::Replication
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
end
