require "string_scanner"
module PG
  alias PGValue = String | Nil | Bool | Int32 | Float32 | Float64 | Time

  # https://github.com/postgres/postgres/blob/master/src/include/catalog/pg_type.h
  abstract class Decoder
    def self.from_oid(oid)
      case oid
      when 16
        BoolDecoder
      when 20, 21, 23 # 20:int8, 21:int2, 23:int4
        IntDecoder
      when 25 # text
        DefaultDecoder
      when 700 # float4
        Float32Decoder
      when 701 # float8
        Float64Decoder
      when 705 # unknown
        DefaultDecoder
      when 1082, 1114, 1184 # 1082:date 1114:ts, 1184:tstz
        TimeDecoder
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

  class TimeDecoder < Decoder
    def decode(value_ptr)
      year       = 1
      month      = 1
      day        = 1
      hour       = 0
      minute     = 0
      second     = 0
      milisecond = 0
      offset     = 0

      str = StringScanner.new(String.new(value_ptr))
      year       = str.scan(/(\d+)/).to_i; str.scan(/-/)
      month      = str.scan(/(\d+)/).to_i; str.scan(/-/)
      day        = str.scan(/(\d+)/).to_i; str.scan(/ /)
      hour       = str.scan(/(\d+)/).to_i; str.scan(/:/)
      minute     = str.scan(/(\d+)/).to_i; str.scan(/:/)
      second     = str.scan(/(\d+)/).to_i; str.scan(/\./)
      milisecond = str.scan(/(\d+)/).to_i
      offset     = str.scan(/([\+|\-]\d+)/).to_i
      Time.new(year, month, day, hour - offset, minute, second, milisecond, Time::Kind::Utc)
    end
  end

end
