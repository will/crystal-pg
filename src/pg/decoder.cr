require "json"

lib LibC
  fun atoi(str : UInt8*) : Int32
end

module PG
  alias PGValue = String | Nil | Bool | Int32 | Float32 | Float64 | Time | JSON::Type

  module Decoder

    abstract class Decoder
      def decode(value_ptr) end

      private def swap32(ptr : UInt8*) : UInt32*
        n = (((((((( 0_u32
         ) | ptr[0] ) << 8
         ) | ptr[1] ) << 8
         ) | ptr[2] ) << 8
         ) | ptr[3] )
        pointerof(n)
      end

      private def swap64(ptr : UInt8*) : UInt64*
        n = (((((((((((((((( 0_u64
         ) | ptr[0] ) << 8
         ) | ptr[1] ) << 8
         ) | ptr[2] ) << 8
         ) | ptr[3] ) << 8
         ) | ptr[4] ) << 8
         ) | ptr[5] ) << 8
         ) | ptr[6] ) << 8
         ) | ptr[7] )
        pointerof(n)
      end
    end

    class DefaultDecoder < Decoder
      def decode(value_ptr)
        String.new(value_ptr)
      end
    end

    class BoolDecoder < Decoder
      def decode(value_ptr)
        case value_ptr.value
        when 0
          false
        when 1
          true
        else
          raise "bad boolean decode: #{value_ptr.value}"
        end
      end
    end

    class IntDecoder < Decoder
      def decode(value_ptr)
        (swap32(value_ptr) as Int32*).value
      end
    end

    class Float32Decoder < Decoder
      # byte swapped in the same way as int4
      def decode(value_ptr)
        (swap32(value_ptr) as Float32*).value
      end
    end

    class Float64Decoder < Decoder
      def decode(value_ptr)
        (swap64(value_ptr) as Float64*).value
      end
    end

    class JsonDecoder < Decoder
      def decode(value_ptr)
        JSON.parse(String.new(value_ptr))
      end
    end

    class JsonbDecoder < Decoder
      def decode(value_ptr)
        # move past single 0x01 byte at the start of jsonb
        JSON.parse(String.new(value_ptr+1))
      end
    end

    class DateDecoder < Decoder
      def decode(value_ptr)
        v = (swap32(value_ptr) as Int32*).value
        return Time.new(2000,1,1, kind: Time::Kind::Utc) + TimeSpan.new(v,0,0,0)
      end
    end

    class TimeDecoder < Decoder
      def decode(value_ptr)
        v = (swap64(value_ptr) as Int64*).value / 1000
        return Time.new(2000,1,1, kind: Time::Kind::Utc) + TimeSpan.new(0,0,0,0,v)
      end
    end

    @@decoders = Hash(Int32, PG::Decoder::Decoder).new
    @@default = DefaultDecoder.new

    def self.from_oid(oid)
      @@decoders[oid]? || @@default
    end

    def self.register_decoder(decoder, oid)
      @@decoders[oid] = decoder
    end

    # https://github.com/postgres/postgres/blob/master/src/include/catalog/pg_type.h
    register_decoder BoolDecoder.new,      16 # bool
    register_decoder IntDecoder.new,       20 # int8
    register_decoder IntDecoder.new,       21 # int2
    register_decoder IntDecoder.new,       23 # int4
    register_decoder DefaultDecoder.new,   25 # text
    register_decoder JsonDecoder.new,     114 # json
    register_decoder JsonbDecoder.new,   3802 # jsonb
    register_decoder Float32Decoder.new,  700 # float4
    register_decoder Float64Decoder.new,  701 # float8
    register_decoder DefaultDecoder.new,  705 # unknown
    register_decoder DateDecoder.new,    1082 # date
    register_decoder TimeDecoder.new,    1114 # timestamp
    register_decoder TimeDecoder.new,    1184 # timestamptz
  end
end
