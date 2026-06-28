module PG::Replication
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
      io << 'd'
      payload = IO::Memory.new.tap { |buf| data.to_io buf }.to_slice
      io.write_bytes payload.bytesize + 4, IO::ByteFormat::NetworkEndian
      io.write payload
    end
  end
end

require "./x_log_data"
require "./keep_alive"
require "./keep_alive_response"
