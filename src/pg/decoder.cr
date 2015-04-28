module PG
  alias PGValue = String | Nil | Bool | Int | Float32 | Float64

  # https://github.com/postgres/postgres/blob/master/src/include/catalog/pg_type.h
  abstract class Decoder
    def self.from_oid(oid)
      case oid
      when 16
        BoolDecoder
      when 20, 21, 23
        IntDecoder
      when 700
        Float32Decoder
      when 701
        Float64Decoder
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

  class IntDecoder < Decoder
    def decode(value_ptr)
      LibC.atoi value_ptr
    end
  end

  class Float32Decoder < Decoder
    def decode(value_ptr)
      LibC.strtof value_ptr, nil
    end
  end

  class Float64Decoder < Decoder
    def decode(value_ptr)
      LibC.atof value_ptr
    end
  end

end
