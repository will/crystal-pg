require "../numeric"

module PG
  module Decoders
    struct RangeDecoder(T)
      include Decoder
      # Decoder to use for boundaries => Range oids
      DECODERS_TO_OID = {
        "Int32" => [3904],
        "Int64" => [3926],
        "Time"  => [
          3912,
          3910,
          3908,
        ],
        "Numeric" => [3906],
      }

      # Range OID => OID of upper/lower boundary
      OIDS_TO_SUBOIDS = {
        3904 => 23,   # int4range
        3926 => 20,   # int8range
        3912 => 1082, # daterange
        3910 => 1114, # tstzrange
        3908 => 1114, # tsrange,
        3906 => 1700, # numrange
      }

      getter oids : Array(Int32)

      # See https://github.com/postgres/postgres/blob/5cbfce562f7cd2aab0cdc4694ce298ec3567930e/src/include/utils/rangetypes.h#L36
      FLAG_EMPTY           = 0b00000001
      FLAG_LOWER_INCLUSIVE = 0b00000010
      FLAG_UPPER_INCLUSIVE = 0b00000100
      FLAG_LOWER_INFINITY  = 0b00001000
      FLAG_UPPER_INFINITY  = 0b00010000

      def initialize(@oids : Array(Int32))
      end

      {% for key, value in DECODERS_TO_OID %}
      private def decode_boundary(io, oid, infinity, type : {{ key.id }}.class )
        if infinity
          \{% if T.nilable? %}
          nil
          \{% else %}
          raise PG::RuntimeError.new("Boundary is infinite but #{T} is not nilable")
          \{% end %}
        else
          bytesize = read_i32(io)
          suboid = OIDS_TO_SUBOIDS[oid]
          Decoders::{{ key.id }}Decoder.new.decode(io, bytesize, suboid)
        end
      end

      PG::Decoders.register_decoder RangeDecoder({{ key.id }}).new({{ value }})
      {% end %}

      private def empty_range(type : Int32.class)
        Range.new(0_i32, 0_i32)
      end

      private def empty_range(type : Int64.class)
        Range.new(0_i64, 0_i64)
      end

      private def empty_range(type : Time.class)
        Range.new(Time.unix(0), Time.unix(0))
      end

      private def empty_range(type : PG::Numeric.class)
        value = PG::Numeric.new(ndigits: 1, weight: 0, sign: PG::Numeric::Sign::Pos.value, dscale: 0, digits: [0] of Int16)

        Range.new(value, value)
      end

      def decode(io, bytesize, oid)
        header = decode_range_header(io)

        if header.empty
          empty_range(T)
        else
          lower = decode_boundary(io, oid, header.lower_infinity, T)
          upper = decode_boundary(io, oid, header.upper_infinity, T)
          Range.new(lower, upper, !header.upper_inclusive)
        end
      end

      def type
        Range(T, T)
      end

      def decode_range_header(io)
        #
        # For discrete types postgres normalizes inclusive/exclusive  to
        # [a, b)
        # (Inclusive lower, exclusive upper) and therefore we do not see FLAG_UPPER_INCLUSIVE
        # If lower and/or upper infinity is set, we will represent this with
        # beginless/endless Range.
        #
        flags = io.read_byte.not_nil!

        RangeHeader.new(
          empty: (FLAG_EMPTY & flags) != 0,
          lower_inclusive: (FLAG_LOWER_INCLUSIVE & flags) != 0,
          lower_infinity: (FLAG_LOWER_INFINITY & flags) != 0,
          upper_inclusive: (FLAG_UPPER_INCLUSIVE & flags) != 0,
          upper_infinity: (FLAG_UPPER_INFINITY & flags) != 0
        )
      end
    end

    record RangeHeader,
      empty : Bool,
      lower_inclusive : Bool,
      lower_infinity : Bool,
      upper_inclusive : Bool,
      upper_infinity : Bool
  end
end
