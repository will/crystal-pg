require "uri"
require "crypto/md5"
require "socket"
require "socket/tcp_socket"
require "socket/unix_socket"
require "openssl/openssl"

DEBUG = ENV["DEBUG"]?

module PQ
  class Connection
    getter soc : UNIXSocket | TCPSocket | OpenSSL::SSL::Socket
    property notice_handler : Notice ->

    def initialize(@conninfo : ConnInfo)
      @established = false
      @notice_handler = Proc(Notice, Void).new { }
      begin
        if @conninfo.host[0] == '/'
          soc = UNIXSocket.new(@conninfo.host)
        else
          soc = TCPSocket.new(@conninfo.host, @conninfo.port)
        end
        soc.sync = false
      rescue e
        raise ConnectionError.new("Cannot establish connection", cause: e)
      end

      @soc = soc
      negotiate_ssl if @soc.is_a?(TCPSocket)
    end

    private def negotiate_ssl
      write_i32 8
      write_i32 80877103
      @soc.flush
      serv_ssl = case c = @soc.read_char
                 when 'S' then true
                 when 'N' then false
                 else
                   raise ConnectionError.new(
                     "Unexpected SSL response from server: #{c.inspect}")
                 end

      if serv_ssl
        @soc = OpenSSL::SSL::Socket.new(@soc, sync_close: true)
      end
    end

    def close
      send_terminate_message
      @soc.close
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
      f = read(soc.read_char)
    end

    def read(frame_type)
      size = read_i32
      slice = read_bytes(size - 4)
      frame = Frame.new(frame_type.not_nil!, slice).tap { |f| p f if DEBUG }

      handle_error_and_notice(frame) ? read : frame
    end

    private def handle_error_and_notice(frame)
      if frame.is_a?(Frame::ErrorResponse)
        handle_error frame
        true
      elsif frame.is_a?(Frame::NoticeResponse)
        handle_notice frame
        true
      else
        false
      end
    end

    private def handle_error(error_frame : Frame::ErrorResponse)
      expect_frame Frame::ReadyForQuery if @established
      notice_handler.call(error_frame.as_notice)
      raise PQError.new(error_frame.fields)
    end

    private def handle_notice(notice_frame : Frame::NoticeResponse)
      notice_handler.call(notice_frame.as_notice)
    end

    def connect
      startup_args = [
        "user", @conninfo.user,
        "database", @conninfo.database,
        "application_name", "crystal",
        "client_encoding", "utf8",
      ]

      startup startup_args

      auth_frame = expect_frame Frame::Authentication
      handle_auth auth_frame

      while !(Frame::ReadyForQuery === read)
      end
      @established = true
    end

    private def handle_auth(auth_frame)
      case auth_frame.type
      when Frame::Authentication::Type::OK
        # no op
      when Frame::Authentication::Type::CleartextPassword
        handle_auth_cleartext
      when Frame::Authentication::Type::MD5Password
        handle_auth_md5 auth_frame.body
      else
        raise ConnectionError.new(
          "unsupported authentication method: #{auth_frame.type}"
        )
      end
    end

    private def handle_auth_cleartext
      send_password_message @conninfo.password
      expect_frame Frame::Authentication
    end

    private def handle_auth_md5(salt)
      inner = Crypto::MD5.hex_digest("#{@conninfo.password}#{@conninfo.user}")

      c = Crypto::MD5::Context.new
      c.update(inner.to_unsafe, inner.bytesize.to_u32)
      c.update(salt.to_unsafe, salt.bytesize.to_u32)
      c.final

      send_password_message "md5#{c.hex}"
      expect_frame Frame::Authentication
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

    def expect_frame(frame_class, type = nil)
      f = type ? read(type) : read
      raise "Expected #{frame_class} but got #{f}" unless frame_class === f
      frame_class.cast(f)
    end

    def send_password_message(password)
      write_chr 'p'
      if password
        write_i32 password.size + 4 + 1
        soc << password
      else
        write_i32 4 + 1
      end
      write_null
      soc.flush
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

    def send_terminate_message
      write_chr 'X'
      write_i32 4
    end
  end
end
