module PG
  abstract class Decoder
    def self.from_oid(oid)
      case oid
      when 16
        BoolDecoder
      else
        DefaultDecoder
      end.new
    end

    def decode(value_ptr) end
  end

  class DefaultDecoder < Decoder
    def decode(value_ptr)
      String.new(value_ptr)
    end
  end

  class BoolDecoder < Decoder
    def decode(value_ptr)
      case value_ptr.value
      when 't'.ord
        true
      when 'f'.ord
        false
      else
        raise "bad boolean decode"
      end
    end
  end
end
