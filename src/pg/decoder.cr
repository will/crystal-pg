require "json"
require "./numeric"

module PG

  alias PGValue = String | Nil | Bool | Int32 | Float32 | Float64 | Time | JSON::Type | PG::Numeric

  # :nodoc:
  module Decoders

    # When subclassing overwrite #decode(io : IO) or #decode(bytes : Slice(UInt8)). Decoder is used via
    # #decode(bytes : Slice(UInt8)) only.
    class Decoder

      def decode(io : IO)
        raise "Not supported, please use #decode(bytes : Slice(UInt8))."
      end

      def decode(bytes : Slice(UInt8))
        decode MemoryIO.new bytes
      end

      {% for type in %w(Int8 UInt8 Int16 UInt16 Int32 UInt32 Int64 UInt64 Float32 Float64) %}
        def decode(type : {{type.id}}.class, io : IO)
          IO::ByteFormat::NetworkEndian.decode {{type.id}}, io
        end
      {% end %}

    end

    class StringDecoder < Decoder
      def decode(bytes : Slice(UInt8))
        String.new bytes
      end
    end

    class CharDecoder < Decoder
      def decode(bytes : Slice(UInt8))
        String.new(bytes)[0]
      end
    end

    class BoolDecoder < Decoder
      def decode(io : IO)
        case value = decode UInt8, io
        when 0
          false
        when 1
          true
        else
          raise "Invalid bool, expected 0 or 1, but got #{value}."
        end
      end
    end

    class Int2Decoder < Decoder
      def decode(io : IO)
        decode Int16, io
      end
    end

    class IntDecoder < Decoder
      def decode(io : IO)
        decode Int32, io
      end
    end

    class UIntDecoder < Decoder
      def decode(io : IO)
        decode UInt32, io
      end
    end

    class Int8Decoder < Decoder
      def decode(io : IO)
        decode Int64, io
      end
    end

    class Float32Decoder < Decoder
      def decode(io : IO)
        decode Float32, io
      end
    end

    class Float64Decoder < Decoder
      def decode(io : IO)
        decode Float64, io
      end
    end

    class PointDecoder < Decoder
      def decode(io : IO)
        {decode(Float64, io), decode(Float64, io)}
      end
    end

    class PathDecoder < Decoder
      def decode(io : IO)
        status = (decode(UInt8, io) == 1_u8 ? :closed : :open)
        polygon = PolygonDecoder.new.decode io
        {status, polygon}
      end
    end

    class PolygonDecoder < Decoder
      def decode(io : IO)
        point_decoder = PointDecoder.new
        count = decode Int32, io
        Array(Tuple(Float64, Float64)).new(count) do
          point_decoder.decode io
        end
      end
    end

    class BoxDecoder < Decoder
      def decode(io : IO)
        point_decoder = PointDecoder.new
        {point_decoder.decode(io), point_decoder.decode(io)}
      end
    end

    class LineDecoder < Decoder
      def decode(io : IO)
        {decode(Float64, io), decode(Float64, io), decode(Float64, io)}
      end
    end

    class JsonDecoder < Decoder
      def decode(bytes : Slice(UInt8))
        JSON.parse String.new(bytes)
      end
    end

    class JsonbDecoder < Decoder
      def decode(bytes : Slice(UInt8))
        if bytes[0] == 0x01
          JSON.parse String.new(bytes + 1)
        else
          raise "Invalid jsonb, expected 0x01 byte."
        end
      end
    end

    JAN_1_2K_TICKS = Time.new(2000, 1, 1, kind: Time::Kind::Utc).ticks

    class DateDecoder < Decoder
      def decode(io : IO)
        v = decode Int32, io
        Time.new(JAN_1_2K_TICKS + (Time::Span::TicksPerDay * v), kind: Time::Kind::Utc)
      end
    end

    class TimeDecoder < Decoder
      def decode(io : IO)
        v = decode(Int64, io) / 1000
        Time.new(JAN_1_2K_TICKS + (Time::Span::TicksPerMillisecond * v), kind: Time::Kind::Utc)
      end
    end

    class UuidDecoder < Decoder
      def decode(bytes : Slice(UInt8))
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
      def decode(bytes : Slice(UInt8))
        bytes
      end
    end

    class NumericDecoder < Decoder
      def decode(io : IO)
        ndigits = decode Int16, io
        weight = decode Int16, io
        sign = decode Int16, io
        dscale = decode Int16, io
        digits = Array(Int16).new(ndigits.to_i32) { decode Int16, io }
        PG::Numeric.new(ndigits, weight, sign, dscale, digits)
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
    register_decoder BoolDecoder.new, 16      # bool
    register_decoder ByteaDecoder.new, 17     # bytea
    register_decoder CharDecoder.new, 18      # "char" (internal type)
    register_decoder StringDecoder.new, 19    # name (internal type)
    register_decoder Int8Decoder.new, 20      # int8 (bigint)
    register_decoder Int2Decoder.new, 21      # int2 (smallint)
    register_decoder IntDecoder.new, 23       # int4 (integer)
    register_decoder StringDecoder.new, 25    # text
    register_decoder UIntDecoder.new, 26      # oid (internal type)
    register_decoder JsonDecoder.new, 114     # json
    register_decoder StringDecoder.new, 142   # xml
    register_decoder JsonbDecoder.new, 3802   # jsonb
    register_decoder Float32Decoder.new, 700  # float4
    register_decoder Float64Decoder.new, 701  # float8
    register_decoder StringDecoder.new, 705   # unknown
    register_decoder StringDecoder.new, 1042  # blchar
    register_decoder StringDecoder.new, 1043  # varchar
    register_decoder DateDecoder.new, 1082    # date
    register_decoder TimeDecoder.new, 1114    # timestamp
    register_decoder NumericDecoder.new, 1700 # numeric
    register_decoder TimeDecoder.new, 1184    # timestamptz
    register_decoder IntDecoder.new, 2206     # regtype
    register_decoder UuidDecoder.new, 2950    # uuid


    def self.register_geo
      register_decoder PointDecoder.new, 600   # point
      register_decoder BoxDecoder.new, 601     # lseg
      register_decoder PathDecoder.new, 602    # path
      register_decoder BoxDecoder.new, 603     # box
      register_decoder PolygonDecoder.new, 604 # polygon
      register_decoder LineDecoder.new, 628    # line
      register_decoder LineDecoder.new, 718    # circle
    end
  end
end
