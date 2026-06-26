module PG::Replication
  struct ErrorFrame < Frame
    getter severity : Severity?
    getter message : String?
    getter detail : String?
    getter hint : String?
    getter misc = [] of {Char, String}

    def initialize(io : IO)
      read(io, Int32) # message length; fields below are null-terminated
      loop do
        case byte = read(io, UInt8)
        when 0   then return
        when 'S' then @severity = Severity.parse(read_string(io))
        when 'M' then @message = read_string(io)
        when 'D' then @detail = read_string(io)
        when 'H' then @hint = read_string(io)
        else
          @misc << {byte.chr, read_string(io)}
        end
      end
    end
  end

  enum Severity
    LOG
    INFO
    DEBUG
    NOTICE
    WARNING
    ERROR
    FATAL
    PANIC
  end
end
