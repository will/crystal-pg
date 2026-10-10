require "../range"

module PG
  module Decoders
    abstract struct RangeDecoder(T, D)
      include Decoder

      abstract def element_decoder : D

      def decode(io, bytesize, oid)
        flags = io.read_byte.not_nil!

        # Check for empty range
        if flags & 0x01 != 0
          return Range(T).empty
        end

        # Read bounds
        lower_infinite = (flags & 0x08) != 0
        upper_infinite = (flags & 0x10) != 0
        lower_inclusive = (flags & 0x02) != 0
        upper_inclusive = (flags & 0x04) != 0

        # Read lower bound
        lower = if lower_infinite
                  nil
                else
                  read_element(io)
                end

        # Read upper bound
        upper = if upper_infinite
                  nil
                else
                  read_element(io)
                end

        Range(T).new(lower, upper, lower_inclusive, upper_inclusive)
      end

      private def read_element(io)
        element_size = read_i32(io)
        if element_size == -1
          nil
        else
          element_decoder.decode(io, element_size, 0)
        end
      end

      def type
        Range(T)
      end
    end

    struct Int4RangeDecoder < RangeDecoder(Int32, Int32Decoder)
      def_oids [
        3904, # int4range
      ]

      def element_decoder : Int32Decoder
        Int32Decoder.new
      end
    end

    struct Int8RangeDecoder < RangeDecoder(Int64, Int64Decoder)
      def_oids [
        3926, # int8range
      ]

      def element_decoder : Int64Decoder
        Int64Decoder.new
      end
    end

    struct NumRangeDecoder < RangeDecoder(Numeric, NumericDecoder)
      def_oids [
        3906, # numrange
      ]

      def element_decoder : NumericDecoder
        NumericDecoder.new
      end
    end

    struct TsRangeDecoder < RangeDecoder(Time, TimeDecoder)
      def_oids [
        3908, # tsrange
      ]

      def element_decoder : TimeDecoder
        TimeDecoder.new
      end

      private def read_element(io)
        element_size = read_i32(io)
        if element_size == -1
          nil
        else
          # tsrange uses timestamp (not timestamptz)
          element_decoder.decode(io, element_size, 1114)
        end
      end
    end

    struct TsTzRangeDecoder < RangeDecoder(Time, TimeDecoder)
      def_oids [
        3910, # tstzrange
      ]

      def element_decoder : TimeDecoder
        TimeDecoder.new
      end

      private def read_element(io)
        element_size = read_i32(io)
        if element_size == -1
          nil
        else
          # tstzrange uses timestamptz
          element_decoder.decode(io, element_size, 1184)
        end
      end
    end

    struct DateRangeDecoder < RangeDecoder(Time, TimeDecoder)
      def_oids [
        3912, # daterange
      ]

      def element_decoder : TimeDecoder
        TimeDecoder.new
      end

      private def read_element(io)
        element_size = read_i32(io)
        if element_size == -1
          nil
        else
          # daterange uses date
          element_decoder.decode(io, element_size, 1082)
        end
      end
    end

    # Register the range decoders
    register_decoder Int4RangeDecoder.new
    register_decoder Int8RangeDecoder.new
    register_decoder NumRangeDecoder.new
    register_decoder TsRangeDecoder.new
    register_decoder TsTzRangeDecoder.new
    register_decoder DateRangeDecoder.new
  end
end
