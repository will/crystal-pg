require "uri"
require "socket"
require "socket/tcp_socket"

DEBUG = ENV["DEBUG"]?

module PQ
  class Connection
    getter soc

    def initialize(@conninfo : ConnInfo)
      @soc = TCPSocket.new(@conninfo.host, @conninfo.port)
      @soc.sync = false
    end

    private def write_i32(i : Int32)
      soc.write_bytes i, IO::ByteFormat::NetworkEndian
    end
    private def write_i32(i)
      write_i32 i.to_i32
    end
    private def write_i16(i : Int16)
      soc.write_bytes i, IO::ByteFormat::NetworkEndian
    end
    private def write_i16(i)
      write_i16 i.to_i16
    end
    private def write_null
      soc.write_byte 0_u8
    end
    private def write_byte(byte)
      soc.write_byte byte
    end
    private def write_chr(chr : Char)
      soc.write_byte chr.ord.to_u8
    end
    private def read_i32
      soc.read_bytes(Int32, IO::ByteFormat::NetworkEndian)
    end
    private def read_i16
      soc.read_bytes(Int16, IO::ByteFormat::NetworkEndian)
    end
    private def read_bytes(count)
      data = Slice(UInt8).new(count)
      soc.read_fully(data)
      data
    end

    def startup(args)
      len = args.reduce(0) { |acc, arg| acc + arg.size + 1 }
      write_i32 len + 8 + 1
      write_i32 0x30000
      args.each { |arg| soc << arg << '\0' }
      write_null
      soc.flush
    end

    def read_data_row
      size = read_i32
      ncols = read_i16
      row = Array(Slice(UInt8)?).new(ncols.to_i32) do
        col_size = read_i32
        if col_size == -1
          nil
        else
          read_bytes(col_size)
        end
      end

      yield row
    end

    def read
      read(soc.read_char)
    end

    def read(frame_type)
      size = read_i32
      slice = read_bytes(size - 4)
      Frame.new(frame_type.not_nil!, slice).tap do |f|
        p f if DEBUG
        handle_error(f) if f.is_a?(Frame::ErrorResponse)
      end
    end

    private def handle_error(error_frame : Frame::ErrorResponse)
      expect_frame Frame::ReadyForQuery
      raise PQError.new(error_frame.fields)
    end

    def connect
      startup_args = [
        "user", @conninfo.user,
        "database", @conninfo.database,
        "application_name", "crystal",
        "client_encoding", "utf8",
      ]

      startup startup_args

      while !(Frame::ReadyForQuery === read)
      end
    end

    def simple_query(query) # , &block : Int16, Slice(UInt8) ->)
      send_query_message(query)
      row_description = expect_frame Frame::RowDescription

      read_all_data_rows { |row| yield row }

      expect_frame Frame::ReadyForQuery
    end

    def read_all_data_rows
      type = soc.read_char
      loop do
        break unless type == 'D'
        read_data_row { |row| yield row }
        type = soc.read_char
      end
      expect_frame Frame::CommandComplete, type
    end

    def extended_query(query, params)
      send_parse_message query
      send_bind_message params
      send_describe_portal_message
      send_execute_message
      send_sync_message
      expect_frame Frame::ParseComplete
      expect_frame Frame::BindComplete
      row_description = expect_frame Frame::RowDescription
      read_all_data_rows { |row| yield row }
      expect_frame Frame::ReadyForQuery
    end

    def expect_frame(frame_class, type = nil)
      f = nil
      loop do
        f = type ? read(type) : read
        break unless f.is_a?(Frame::NoticeResponse)
      end
      raise "Expected #{frame_class} but got #{f}" unless frame_class === f
      frame_class.cast(f)
    end

    def send_query_message(query)
      write_chr 'Q'
      write_i32 query.size + 4 + 1
      soc << query
      write_null
      soc.flush
    end

    def send_parse_message(query)
      write_chr 'P'
      write_i32 query.size + 4 + 1 + 2 + 1
      write_null # prepared statment name
      soc << query
      write_i16 0 # don't give any param types
      write_null
      puts ">> parse" if DEBUG
    end

    def send_bind_message(params)
      nparams = params.size
      total_size = params.reduce(0) do |acc, p|
        acc + 4 + (p.size == -1 ? 0 : p.size)
      end

      write_chr 'B'
      write_i32 4 + 1 + 1 + 2 + (2*nparams) + 2 + total_size + 2 + 2
      write_null        # unnamed destination portal
      write_null        # unnamed prepared statment
      write_i16 nparams # number of params format codes to follow
      params.each { |p| write_i16 p.format }
      write_i16 nparams # number of params to follow
      params.each do |p|
        write_i32 p.size
        p.slice.each { |byte| write_byte byte }
      end
      write_i16 1 # number of following return types (1 means apply next for all)
      write_i16 1 # all results as binary

      puts ">> my new bind" if DEBUG
    end

    def send_describe_portal_message
      write_chr 'D'
      write_i32 4 + 1 + 1
      write_chr 'P'
      write_null
    end

    def send_execute_message
      write_chr 'E'
      write_i32 4 + 1 + 4
      write_null  # unnamed portal
      write_i32 0 # unlimited maximum rows
      puts ">> exec" if DEBUG
    end

    def send_sync_message
      write_chr 'S'
      write_i32 4
      soc.flush
      puts ">> sync" if DEBUG
    end
  end
end
