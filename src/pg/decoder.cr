require "json"

module PG
  alias PGValue = String | Nil | Bool | Int32 | Float32 | Float64 | Time | JSON::Type | PG::Numeric

  # :nodoc:
  module Decoders
    abstract class Decoder
      abstract def decode(bytes)

      private def swap16(slice : Slice(UInt8))
        swap16(slice.pointer(0))
      end

      private def swap16(ptr : UInt8*) : UInt16
        ((((0_u16
          ) | ptr[0]) << 8
          ) | ptr[1])
      end

      private def swap32(slice : Slice(UInt8))
        swap32(slice.pointer(0))
      end

      private def swap32(ptr : UInt8*) : UInt32
        ((((((((0_u32
          ) | ptr[0]) << 8
          ) | ptr[1]) << 8
          ) | ptr[2]) << 8
          ) | ptr[3])
      end

      private def swap64(slice : Slice(UInt8))
        swap64(slice.pointer(0))
      end

      private def swap64(ptr : UInt8*) : UInt64
        ((((((((((((((((0_u64
          ) | ptr[0]) << 8
          ) | ptr[1]) << 8
          ) | ptr[2]) << 8
          ) | ptr[3]) << 8
          ) | ptr[4]) << 8
          ) | ptr[5]) << 8
          ) | ptr[6]) << 8
          ) | ptr[7])
      end
    end

    class StringDecoder < Decoder
      def decode(bytes)
        String.new(bytes)
      end
    end

    class CharDecoder < Decoder
      def decode(bytes)
        String.new(bytes)[0]
      end
    end

    class BoolDecoder < Decoder
      def decode(bytes)
        case bytes[0]
        when 0
          false
        when 1
          true
        else
          raise "bad boolean decode: #{bytes[0]}"
        end
      end
    end

    class Int2Decoder < Decoder
      def decode(bytes)
        swap16(bytes).to_i16
      end
    end

    class IntDecoder < Decoder
      def decode(bytes)
        swap32(bytes).to_i32
      end
    end

    class UIntDecoder < Decoder
      def decode(bytes)
        swap32(bytes).to_u32
      end
    end

    class Int8Decoder < Decoder
      def decode(bytes)
        swap64(bytes).to_i64
      end
    end

    class Float32Decoder < Decoder
      # byte swapped in the same way as int4
      def decode(bytes)
        u32 = swap32(bytes)
        (pointerof(u32).as(Float32*)).value
      end
    end

    class Float64Decoder < Decoder
      def decode(bytes)
        u64 = swap64(bytes)
        (pointerof(u64).as(Float64*)).value
      end
    end

    alias PGInt32Array = Int32? | Array(PGInt32Array)

    class ArrayDecoder < Decoder
      def decode(bytes)
        puts
        dimensions = swap32(bytes).to_i
        has_null = swap32(bytes + 4) == 1 ? true : false
        oid = swap32(bytes + 8)
        dim_info = Array(NamedTuple(dim: UInt32, lbound: UInt32)).new(dimensions) do |i|
          offset = 12 + (8*i)
          {
            dim: swap32(bytes + offset),
            lbound: swap32(bytes + (offset + 4))
          }
        end
        data_start = (8*dimensions)+8+4
        puts [bytes.size, (bytes+data_start).size]


        p [dimensions, has_null, oid, dim_info]
        p bytes

        # using any other offset here, such as +1 or -1 avoids the segfualt
        puts (bytes + (data_start )).hexdump

        #but the hexdump itself is not segfualting, these next two prints make it
        p bytes
        puts "ok"


        #Array(PGInt32Array).new(dim_info[0][:dim].to_i) do |i|
        #  get_element(bytes, dim_info, 0, i)
        #end

        # the segfault includes the type of the result here
        # ["hi"]  # [4344595745] *Array(String)@Object#inspect:String +33
        # vs
        [3]  # [4315101473] *Array(Int32)@Object#inspect:String +33
      end

      def get_element(bytes, dim_info, depth, pos)
        if depth == (dim_info.size-1)
          0
        else
          1
        end
      end


    end

    class PointDecoder < Decoder
      def decode(bytes)
        x = swap64(bytes)
        y = swap64(bytes + 8)

        Geo::Point.new(
          (pointerof(x).as(Float64*)).value,
          (pointerof(y).as(Float64*)).value,
        )
      end
    end

    class PathDecoder < Decoder
      def initialize
        @polygon = PolygonDecoder.new
      end

      def decode(bytes)
        closed = bytes[0] == 1_u8
        Geo::Path.new(@polygon.decode(bytes + 1), closed)
      end
    end

    class PolygonDecoder < Decoder
      def decode(bytes)
        c = swap32(bytes)
        count = (pointerof(c).as(Int32*)).value

        Array.new(count) do |i|
          offset = i*16 + 4
          x = swap64(bytes + offset)
          y = swap64(bytes + (offset + 8))

          Geo::Point.new(
            (pointerof(x).as(Float64*)).value,
            (pointerof(y).as(Float64*)).value,
          )
        end
      end
    end

    class BoxDecoder < Decoder
      def decode(bytes)
        x1 = swap64(bytes)
        y1 = swap64(bytes + 8)
        x2 = swap64(bytes + 16)
        y2 = swap64(bytes + 24)

        Geo::Box.new(
          (pointerof(x1).as(Float64*)).value,
          (pointerof(y1).as(Float64*)).value,
          (pointerof(x2).as(Float64*)).value,
          (pointerof(y2).as(Float64*)).value,
        )
      end
    end

    class LineSegmentDecoder < Decoder
      def decode(bytes)
        x1 = swap64(bytes)
        y1 = swap64(bytes + 8)
        x2 = swap64(bytes + 16)
        y2 = swap64(bytes + 24)

        Geo::LineSegment.new(
          (pointerof(x1).as(Float64*)).value,
          (pointerof(y1).as(Float64*)).value,
          (pointerof(x2).as(Float64*)).value,
          (pointerof(y2).as(Float64*)).value,
        )
      end
    end

    class LineDecoder < Decoder
      def decode(bytes)
        a = swap64(bytes)
        b = swap64(bytes + 8)
        c = swap64(bytes + 16)

        Geo::Line.new(
          (pointerof(a).as(Float64*)).value,
          (pointerof(b).as(Float64*)).value,
          (pointerof(c).as(Float64*)).value,
        )
      end
    end

    class CircleDecoder < Decoder
      def decode(bytes)
        a = swap64(bytes)
        b = swap64(bytes + 8)
        c = swap64(bytes + 16)

        Geo::Circle.new(
          (pointerof(a).as(Float64*)).value,
          (pointerof(b).as(Float64*)).value,
          (pointerof(c).as(Float64*)).value,
        )
      end
    end

    class JsonDecoder < Decoder
      def decode(bytes)
        JSON.parse(String.new(bytes))
      end
    end

    class JsonbDecoder < Decoder
      def decode(bytes)
        # move past single 0x01 byte at the start of jsonb
        JSON.parse(String.new(bytes + 1))
      end
    end

    JAN_1_2K_TICKS = Time.new(2000, 1, 1, kind: Time::Kind::Utc).ticks

    class DateDecoder < Decoder
      def decode(bytes)
        v = swap32(bytes).to_i32
        Time.new(JAN_1_2K_TICKS + (Time::Span::TicksPerDay * v), kind: Time::Kind::Utc)
      end
    end

    class TimeDecoder < Decoder
      def decode(bytes)
        v = swap64(bytes).to_i64 / 1000
        Time.new(JAN_1_2K_TICKS + (Time::Span::TicksPerMillisecond * v), kind: Time::Kind::Utc)
      end
    end

    class UuidDecoder < Decoder
      def decode(bytes)
        String.new(36) do |buffer|
          buffer[8] = buffer[13] = buffer[18] = buffer[23] = 45_u8
          bytes[0, 4].hexstring(buffer + 0)
          bytes[4, 2].hexstring(buffer + 9)
          bytes[6, 2].hexstring(buffer + 14)
          bytes[8, 2].hexstring(buffer + 19)
          bytes[10, 6].hexstring(buffer + 24)
          {36, 36}
        end
      end
    end

    class ByteaDecoder < Decoder
      def decode(bytes)
        bytes
      end
    end

    class NumericDecoder < Decoder
      def decode(bytes)
        ndigits = i16 bytes[0, 2]
        weight = i16 bytes[2, 2]
        sign = i16 bytes[4, 2]
        dscale = i16 bytes[6, 2]
        digits = (0...ndigits).map { |i| i16 bytes[i*2 + 8, 2] }
        PG::Numeric.new(ndigits, weight, sign, dscale, digits)
      end

      private def i16(bytes)
        swap16(bytes).to_i16
      end
    end

    @@decoders = Hash(Int32, PG::Decoders::Decoder).new(ByteaDecoder.new)

    def self.from_oid(oid)
      @@decoders[oid]
    end

    def self.register_decoder(decoder, oid)
      @@decoders[oid] = decoder
    end

    # https://github.com/postgres/postgres/blob/master/src/include/catalog/pg_type.h
    register_decoder BoolDecoder.new, 16         # bool
    register_decoder ByteaDecoder.new, 17        # bytea
    register_decoder CharDecoder.new, 18         # "char" (internal type)
    register_decoder StringDecoder.new, 19       # name (internal type)
    register_decoder Int8Decoder.new, 20         # int8 (bigint)
    register_decoder Int2Decoder.new, 21         # int2 (smallint)
    register_decoder IntDecoder.new, 23          # int4 (integer)
    register_decoder StringDecoder.new, 25       # text
    register_decoder UIntDecoder.new, 26         # oid (internal type)
    register_decoder JsonDecoder.new, 114        # json
    register_decoder StringDecoder.new, 142      # xml
    register_decoder JsonbDecoder.new, 3802      # jsonb
    register_decoder Float32Decoder.new, 700     # float4
    register_decoder Float64Decoder.new, 701     # float8
    register_decoder StringDecoder.new, 705      # unknown
    register_decoder StringDecoder.new, 1042     # blchar
    register_decoder StringDecoder.new, 1043     # varchar
    register_decoder DateDecoder.new, 1082       # date
    register_decoder TimeDecoder.new, 1114       # timestamp
    register_decoder NumericDecoder.new, 1700    # numeric
    register_decoder TimeDecoder.new, 1184       # timestamptz
    register_decoder IntDecoder.new, 2206        # regtype
    register_decoder UuidDecoder.new, 2950       # uuid
    register_decoder PointDecoder.new, 600       # point
    register_decoder LineSegmentDecoder.new, 601 # lseg
    register_decoder PathDecoder.new, 602        # path
    register_decoder BoxDecoder.new, 603         # box
    register_decoder PolygonDecoder.new, 604     # polygon
    register_decoder LineDecoder.new, 628        # line
    register_decoder CircleDecoder.new, 718      # circle

    register_decoder ArrayDecoder.new, 1007 # arary
  end
end
