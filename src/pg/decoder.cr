require "json"

module PG
  alias PGValue = String | Nil | Bool | Int32 | Float32 | Float64 | Time | JSON::Type | PG::Numeric

  # :nodoc:
  module Decoders
    abstract class Decoder
      abstract def decode(io, bytesize)
      abstract def type

      def read(io, type)
        io.read_bytes(type, IO::ByteFormat::NetworkEndian)
      end

      def read_i16(io)
        read(io, Int16)
      end

      def read_i32(io)
        read(io, Int32)
      end

      def read_i64(io)
        read(io, Int64)
      end

      def read_u32(io)
        read(io, UInt32)
      end

      def read_u64(io)
        read(io, UInt64)
      end

      def read_f32(io)
        read(io, Float32)
      end

      def read_f64(io)
        read(io, Float64)
      end
    end

    class StringDecoder < Decoder
      def decode(io, bytesize)
        String.new(bytesize) do |buffer|
          io.read_fully(Slice.new(buffer, bytesize))
          {bytesize, 0}
        end
      end

      def type
        String
      end
    end

    class CharDecoder < Decoder
      def decode(io, bytesize)
        # TODO: can be done without creating an intermediate string
        String.new(bytesize) do |buffer|
          io.read_fully(Slice.new(buffer, bytesize))
          {bytesize, 0}
        end[0]
      end

      def type
        Char
      end
    end

    class BoolDecoder < Decoder
      def decode(io, bytesize)
        case byte = io.read_byte
        when 0
          false
        when 1
          true
        else
          raise "bad boolean decode: #{byte}"
        end
      end

      def type
        Bool
      end
    end

    class Int16Decoder < Decoder
      def decode(io, bytesize)
        read_i16(io)
      end

      def type
        Int16
      end
    end

    class Int32Decoder < Decoder
      def decode(io, bytesize)
        read_i32(io)
      end

      def type
        Int32
      end
    end

    class Int64Decoder < Decoder
      def decode(io, bytesize)
        read_u64(io).to_i64
      end

      def type
        Int64
      end
    end

    class UIntDecoder < Decoder
      def decode(io, bytesize)
        read_u32(io)
      end

      def type
        UInt32
      end
    end

    class Float32Decoder < Decoder
      # byte swapped in the same way as int4
      def decode(io, bytesize)
        read_f32(io)
      end

      def type
        Float32
      end
    end

    class Float64Decoder < Decoder
      def decode(io, bytesize)
        read_f64(io)
      end

      def type
        Float64
      end
    end

    class PointDecoder < Decoder
      def decode(io, bytesize)
        Geo::Point.new(read_f64(io), read_f64(io))
      end

      def type
        Geo::Point
      end
    end

    class PathDecoder < Decoder
      def initialize
        @polygon = PolygonDecoder.new
      end

      def decode(io, bytesize)
        byte = io.read_byte.not_nil!
        closed = byte == 1_u8
        Geo::Path.new(@polygon.decode(io, bytesize - 1), closed)
      end

      def type
        Geo::Path
      end
    end

    class PolygonDecoder < Decoder
      def initialize
        @point_decoder = PointDecoder.new
      end

      def decode(io, bytesize)
        c = read_u32(io)
        count = (pointerof(c).as(Int32*)).value
        Array.new(count) do |i|
          @point_decoder.decode(io, 16)
        end
      end

      def type
        Geo::Polygon
      end
    end

    class BoxDecoder < Decoder
      def decode(io, bytesize)
        Geo::Box.new(read_f64(io), read_f64(io), read_f64(io), read_f64(io))
      end

      def type
        Geo::Box
      end
    end

    class LineSegmentDecoder < Decoder
      def decode(io, bytesize)
        Geo::LineSegment.new(read_f64(io), read_f64(io), read_f64(io), read_f64(io))
      end

      def type
        Geo::LineSegment
      end
    end

    class LineDecoder < Decoder
      def decode(io, bytesize)
        Geo::Line.new(read_f64(io), read_f64(io), read_f64(io))
      end

      def type
        Geo::Line
      end
    end

    class CircleDecoder < Decoder
      def decode(io, bytesize)
        Geo::Circle.new(read_f64(io), read_f64(io), read_f64(io))
      end

      def type
        Geo::Circle
      end
    end

    class JsonDecoder < Decoder
      def decode(io, bytesize)
        string = String.new(bytesize) do |buffer|
          io.read_fully(Slice.new(buffer, bytesize))
          {bytesize, 0}
        end
        JSON.parse(string)
      end

      def type
        JSON::Any
      end
    end

    class JsonbDecoder < Decoder
      def decode(io, bytesize)
        io.read_byte

        string = String.new(bytesize - 1) do |buffer|
          io.read_fully(Slice.new(buffer, bytesize - 1))
          {bytesize, 0}
        end
        JSON.parse(string)
      end

      def type
        JSON::Any
      end
    end

    JAN_1_2K_TICKS = Time.new(2000, 1, 1, kind: Time::Kind::Utc).ticks

    class DateDecoder < Decoder
      def decode(io, bytesize)
        v = read_i32(io)
        Time.new(JAN_1_2K_TICKS + (Time::Span::TicksPerDay * v), kind: Time::Kind::Utc)
      end

      def type
        Time
      end
    end

    class TimeDecoder < Decoder
      def decode(io, bytesize)
        v = read_i64(io) / 1000
        Time.new(JAN_1_2K_TICKS + (Time::Span::TicksPerMillisecond * v), kind: Time::Kind::Utc)
      end

      def type
        Time
      end
    end

    class UuidDecoder < Decoder
      def decode(io, bytesize)
        bytes = uninitialized UInt8[6]

        String.new(36) do |buffer|
          buffer[8] = buffer[13] = buffer[18] = buffer[23] = 45_u8

          slice = bytes.to_slice[0, 4]

          io.read(slice)
          slice.hexstring(buffer + 0)

          slice = bytes.to_slice[0, 2]

          io.read(slice)
          slice.hexstring(buffer + 9)

          io.read(slice)
          slice.hexstring(buffer + 14)

          io.read(slice)
          slice.hexstring(buffer + 19)

          slice = bytes.to_slice
          io.read(slice)
          slice.hexstring(buffer + 24)

          {36, 36}
        end
      end

      def type
        String
      end
    end

    class ByteaDecoder < Decoder
      def decode(io, bytesize)
        slice = Bytes.new(bytesize)
        io.read_fully(slice)
        slice
      end

      def type
        Bytes
      end
    end

    class NumericDecoder < Decoder
      def decode(io, bytesize)
        ndigits = read_i16(io)
        weight = read_i16(io)
        sign = read_i16(io)
        dscale = read_i16(io)
        digits = (0...ndigits).map { |i| read_i16(io) }
        PG::Numeric.new(ndigits, weight, sign, dscale, digits)
      end

      def type
        PG::Numeric
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
    register_decoder Int64Decoder.new, 20        # int8 (bigint)
    register_decoder Int16Decoder.new, 21        # int2 (smallint)
    register_decoder Int32Decoder.new, 23        # int4 (integer)
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
    register_decoder Int32Decoder.new, 2206      # regtype
    register_decoder UuidDecoder.new, 2950       # uuid
    register_decoder PointDecoder.new, 600       # point
    register_decoder LineSegmentDecoder.new, 601 # lseg
    register_decoder PathDecoder.new, 602        # path
    register_decoder BoxDecoder.new, 603         # box
    register_decoder PolygonDecoder.new, 604     # polygon
    register_decoder LineDecoder.new, 628        # line
    register_decoder CircleDecoder.new, 718      # circle
  end
end

require "./decoders/*"
