require "json"

lib LibC
  fun atoi(str : UInt8*) : Int32
end

module PG
  alias PGValue = String | Nil | Bool | Int32 | Float32 | Float64 | Time | JSON::Type

  module Decoder

    abstract class Decoder
      abstract def decode(value_ptr)

      private def swap16(ptr : UInt8*) : UInt16
        (((( 0_u16
          ) | ptr[0] ) << 8
          ) | ptr[1] )
      end

      private def swap32(ptr : UInt8*) : UInt32
        (((((((( 0_u32
          ) | ptr[0] ) << 8
          ) | ptr[1] ) << 8
          ) | ptr[2] ) << 8
          ) | ptr[3] )
      end

      private def swap64(ptr : UInt8*) : UInt64
        (((((((((((((((( 0_u64
          ) | ptr[0] ) << 8
          ) | ptr[1] ) << 8
          ) | ptr[2] ) << 8
          ) | ptr[3] ) << 8
          ) | ptr[4] ) << 8
          ) | ptr[5] ) << 8
          ) | ptr[6] ) << 8
          ) | ptr[7] )
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

    class Int2Decoder < Decoder
      def decode(value_ptr)
        swap16(value_ptr).to_i16
      end
    end

    class IntDecoder < Decoder
      def decode(value_ptr)
        swap32(value_ptr).to_i32
      end
    end

    class Int8Decoder < Decoder
      def decode(value_ptr)
        swap64(value_ptr).to_i64
      end
    end

    class Float32Decoder < Decoder
      # byte swapped in the same way as int4
      def decode(value_ptr)
        u32 = swap32(value_ptr)
        (pointerof(u32) as Float32*).value
      end
    end

    class Float64Decoder < Decoder
      def decode(value_ptr)
        u64 = swap64(value_ptr)
        (pointerof(u64) as Float64*).value
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

    JAN_1_2K_TICKS = Time.new(2000,1,1, kind: Time::Kind::Utc).ticks

    class DateDecoder < Decoder
      def decode(value_ptr)
        v = swap32(value_ptr).to_i32
        Time.new(JAN_1_2K_TICKS + (Time::Span::TicksPerDay * v), kind: Time::Kind::Utc)
      end
    end

    class TimeDecoder < Decoder
      def decode(value_ptr)
        v = swap64(value_ptr).to_i64 / 1000
        Time.new(JAN_1_2K_TICKS + (Time::Span::TicksPerMillisecond * v), kind: Time::Kind::Utc)
      end
    end

    class UuidDecoder < Decoder
      def decode(value_ptr)
        bytes = value_ptr.to_slice(16)
        String.new(36) do |buffer|
          buffer[8] = buffer[13] = buffer[18] = buffer[23] = 45_u8
          bytes[ 0, 4].hexstring(buffer + 0)
          bytes[ 4, 2].hexstring(buffer + 9)
          bytes[ 6, 2].hexstring(buffer + 14)
          bytes[ 8, 2].hexstring(buffer + 19)
          bytes[10, 6].hexstring(buffer + 24)
          {36, 36}
        end
      end
    end

    @@decoders = Hash(Int32, PG::Decoder::Decoder).new(DefaultDecoder.new)

    def self.from_oid(oid)
      @@decoders[oid]
    end

    def self.register_decoder(decoder, oid)
      @@decoders[oid] = decoder
    end

    # https://github.com/postgres/postgres/blob/master/src/include/catalog/pg_type.h
    register_decoder    BoolDecoder.new,   16 # bool
    register_decoder    Int8Decoder.new,   20 # int8 (bigint)
    register_decoder    Int2Decoder.new,   21 # int2 (smallint)
    register_decoder     IntDecoder.new,   23 # int4 (integer)
    register_decoder DefaultDecoder.new,   25 # text
    register_decoder    JsonDecoder.new,  114 # json
    register_decoder   JsonbDecoder.new, 3802 # jsonb
    register_decoder Float32Decoder.new,  700 # float4
    register_decoder Float64Decoder.new,  701 # float8
    register_decoder DefaultDecoder.new,  705 # unknown
    register_decoder    DateDecoder.new, 1082 # date
    register_decoder    TimeDecoder.new, 1114 # timestamp
    register_decoder    TimeDecoder.new, 1184 # timestamptz
    register_decoder    UuidDecoder.new, 2950 # uuid
  end
end
