module PG
  alias PGValue = String | Nil | Bool | Int32 | Float32 | Float64 | Time

  module Decoder
    # https://github.com/postgres/postgres/blob/master/src/include/catalog/pg_type.h
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

    abstract class Decoder
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
        curr = value_ptr

        curr, year   = get_next_int(curr)
        curr, month  = get_next_int(curr)
        curr, day    = get_next_int(curr)
        curr, hour   = get_next_int(curr)
        curr, minute = get_next_int(curr)
        curr, second = get_next_int(curr)
        if (curr-1).value == '.'.ord
          curr, fraction = get_next_int(curr)
        else
          fraction = 0
        end
        sign = (curr-1).value == '-'.ord ? -1 : 1
        curr, offset = get_next_int(curr)
        milisecond = fraction_to_mili(fraction)

        t = Time.new(year, month, day, hour, minute, second, milisecond, Time::Kind::Utc)

        return apply_offset(t, offset*sign)
      end

      private def get_next_int(curr)
        return curr, 0 if curr.value == 0
        int = 0
        while curr.value >= 48 && curr.value <= 57
          int = (int*10) + (curr.value - 48)
          curr += 1
        end
        curr += 1 unless curr.value == 0
        return curr,int
      end

      # Postgres returns microseconds, Crystal Time only supports miliseconds
      private def fraction_to_mili(frac)
        if frac < 10
          frac * 100
        elsif frac < 100
          frac * 10
        elsif frac > 1000
          frac / 1000
        else
          frac
        end
      end

      private def apply_offset(t, offset)
        if offset == 0
          t
        else
          t - TimeSpan.new(offset,0,0)
        end
      end
    end
  end
end
