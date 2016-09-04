module PG
  module Decoders
    class ArrayDecoder(T, A, D) < Decoder
      class DataExtractor(D)
        include SwapHelpers

        def initialize(@data : Slice(UInt8))
          @pos = 0
          @decoder = D.new
        end

        def get_next
          ptr = @data.pointer(4)
          size = swap32(ptr + @pos).to_i
          @pos += 4
          if size == -1
            nil
          else
            item = @decoder.decode(ptr + @pos)
            @pos += size
            item
          end
        end
      end

      def decode(bytes)
        dimensions = swap32(bytes).to_i
        has_null = swap32(bytes + 4) == 1 ? true : false
        # oid = swap32(bytes + 8) # unused but in header
        dim_info = Array(NamedTuple(dim: Int32, lbound: Int32)).new(dimensions) do |i|
          offset = 12 + (8*i)
          {
            dim:    swap32(bytes + offset).to_i,
            lbound: swap32(bytes + (offset + 4)).to_i,
          }
        end
        data_start = (8*dimensions) + 8 + 4 # advance past end of header

        extractor = DataExtractor(D).new(bytes + data_start)

        if dimensions == 1 && dim_info.first[:lbound] == 1
          # allow casting down to unnested crystal arrays
          build_simple_array(has_null, extractor, dim_info.first[:dim])
        else
          if dim_info.any? { |di| di[:lbound] < 1 }
            raise PG::RuntimeError.new("Only lower-bounds >= 1 are supported")
          end

          # recursively build nested array
          get_element(extractor, dim_info)
        end
      end

      def build_simple_array(has_null, extractor, size)
        if has_null
          Array(T?).new(size) { extractor.get_next }
        else
          Array(T).new(size) { extractor.get_next.not_nil! }
        end
      end

      def get_element(extractor, dim_info)
        if dim_info.size == 1
          lbound = dim_info.first[:lbound] - 1 # in lower-bound is not 1
          Array(A).new(dim_info.first[:dim] + lbound) do |i|
            i < lbound ? nil : extractor.get_next
          end
        else
          Array(A).new(dim_info.first[:dim]) do |i|
            get_element(extractor, dim_info[1..-1])
          end
        end
      end

    end
  end

  macro array_type(oid, t)
    alias {{t}}Array = {{t}}? | Array({{t}}Array)
    module Decoders
      register_decoder ArrayDecoder({{t}}, {{t}}Array, {{t}}Decoder).new, {{oid}}
    end
  end


  array_type 1000, Bool
  array_type 1002, Char
  array_type 1005, Int16
  array_type 1007, Int32
  array_type 1009, String
  array_type 1016, Int64
  array_type 1021, Float32
  array_type 1022, Float64
end
