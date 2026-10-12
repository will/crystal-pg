module PG
  module Decoders
    module RangeDecoding
      # Range flags from PostgreSQL range format
      RANGE_EMPTY  = 0x01
      RANGE_LB_INC = 0x02 # Lower bound inclusive
      RANGE_UB_INC = 0x04 # Upper bound inclusive
      RANGE_LB_INF = 0x08 # Lower bound infinite
      RANGE_UB_INF = 0x10 # Upper bound infinite

      private def decode_range(io)
        flags = io.read_byte.not_nil!
        empty = (flags & RANGE_EMPTY) != 0

        return empty_range if empty

        lower_bound_inclusive = (flags & RANGE_LB_INC) != 0
        upper_bound_inclusive = (flags & RANGE_UB_INC) != 0
        lower_bound_infinite = (flags & RANGE_LB_INF) != 0
        upper_bound_infinite = (flags & RANGE_UB_INF) != 0

        lower = if lower_bound_infinite
                  nil
                else
                  len = read_i32(io)
                  decode_element(io)
                end

        upper = if upper_bound_infinite
                  nil
                else
                  len = read_i32(io)
                  decode_element(io)
                end

        PG::Range.new(
          lower,
          upper,
          lower_inclusive: lower_bound_inclusive,
          upper_inclusive: upper_bound_inclusive
        )
      end
    end

    # Abstract base class for range decoders with common logic
    abstract struct RangeDecoder(T)
      include Decoder
      include RangeDecoding

      def decode(io, bytesize, oid)
        decode_range(io)
      end

      def type
        PG::Range(T)
      end

      abstract def decode_element(io)
      abstract def empty_range
    end

    struct Int4RangeDecoder < RangeDecoder(Int32)
      def_oids [3904] # int4range

      def decode_element(io)
        Int32Decoder.new.decode(io, nil, nil)
      end

      def empty_range
        PG::Range(Int32).empty
      end
    end

    struct Int8RangeDecoder < RangeDecoder(Int64)
      def_oids [3926] # int8range

      def decode_element(io)
        Int64Decoder.new.decode(io, nil, nil)
      end

      def empty_range
        PG::Range(Int64).empty
      end
    end

    struct DateRangeDecoder < RangeDecoder(Time)
      def_oids [3912] # daterange

      def decode_element(io)
        TimeDecoder.new.decode(io, nil, TimeDecoder::OID::DATE)
      end

      def empty_range
        PG::Range(Time).empty
      end
    end

    struct TsRangeDecoder < RangeDecoder(Time)
      def_oids [3908] # tsrange

      def decode_element(io)
        TimeDecoder.new.decode(io, nil, TimeDecoder::OID::TIMESTAMP)
      end

      def empty_range
        PG::Range(Time).empty
      end
    end

    struct TstzRangeDecoder < RangeDecoder(Time)
      def_oids [3910] # tstzrange

      def decode_element(io)
        TimeDecoder.new.decode(io, nil, TimeDecoder::OID::TIMESTAMPTZ)
      end

      def empty_range
        PG::Range(Time).empty
      end
    end

    struct NumRangeDecoder < RangeDecoder(PG::Numeric)
      def_oids [3906] # numrange

      def decode_element(io)
        NumericDecoder.new.decode(io, nil, nil)
      end

      def empty_range
        PG::Range(PG::Numeric).empty
      end
    end

    # Abstract base class for multirange decoders with common logic
    abstract struct MultiRangeDecoder(T)
      include Decoder
      include RangeDecoding

      def decode(io, bytesize, oid)
        # Multirange format: 4-byte count followed by count range elements
        count = read_i32(io)
        Array(PG::Range(T)).new(count) do
          # Each range element has a 4-byte length followed by the range data
          read_i32(io)

          decode_range(io)
        end
      end

      def type
        Array(PG::Range(T))
      end

      abstract def decode_element(io)
      abstract def empty_range
    end

    struct Int4MultiRangeDecoder < MultiRangeDecoder(Int32)
      def_oids [4451] # int4multirange

      def decode_element(io)
        Int32Decoder.new.decode(io, nil, nil)
      end

      def empty_range
        PG::Range(Int32).empty
      end
    end

    struct Int8MultiRangeDecoder < MultiRangeDecoder(Int64)
      def_oids [4536] # int8multirange

      def decode_element(io)
        Int64Decoder.new.decode(io, nil, nil)
      end

      def empty_range
        PG::Range(Int64).empty
      end
    end

    struct DateMultiRangeDecoder < MultiRangeDecoder(Time)
      def_oids [4535] # datemultirange

      def decode_element(io)
        TimeDecoder.new.decode(io, nil, TimeDecoder::OID::DATE)
      end

      def empty_range
        PG::Range(Time).empty
      end
    end

    struct TsMultiRangeDecoder < MultiRangeDecoder(Time)
      def_oids [4533] # tsmultirange

      def decode_element(io)
        TimeDecoder.new.decode(io, nil, TimeDecoder::OID::TIMESTAMP)
      end

      def empty_range
        PG::Range(Time).empty
      end
    end

    struct TstzMultiRangeDecoder < MultiRangeDecoder(Time)
      def_oids [4534] # tstzmultirange

      def decode_element(io)
        TimeDecoder.new.decode(io, nil, TimeDecoder::OID::TIMESTAMPTZ)
      end

      def empty_range
        PG::Range(Time).empty
      end
    end

    struct NumMultiRangeDecoder < MultiRangeDecoder(PG::Numeric)
      def_oids [4532] # nummultirange

      def decode_element(io)
        NumericDecoder.new.decode(io, nil, nil)
      end

      def empty_range
        PG::Range(PG::Numeric).empty
      end
    end
  end
end
