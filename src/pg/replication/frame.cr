require "./read"

module PG::Replication
  abstract struct Frame
    include Read

    def self.from_io(io : IO) : self
      case byte = io.read_byte
      when nil
        raise IO::EOFError.new("Connection was unexpectedly terminated")
      when 'W'
        CopyBoth.new(io)
      when 'd'
        CopyData.new(io)
      when 'E'
        ErrorFrame.new(io)
      else
        raise Error.new("Unexpected byte marker: 0x#{byte.to_s(16)} (#{byte.chr.inspect})")
      end
    end
  end
end

require "./copy_both"
require "./copy_data"
require "./error_frame"
