module PG
  module Decoders
    class ArrayDecoder(T, A, D) < Decoder
      class DataExtractor(D)
        def initialize(@io : IO)
          @decoder = D.new
        end

        def get_next
          bytesize = @decoder.read_i32(@io)
          if bytesize == -1
            nil
          else
            @decoder.decode(@io, bytesize)
          end
        end
      end

      def decode(io, bytesize)
        dimensions = read_i32(io)
        bytesize -= 4

        has_null = read_i32(io) == 1
        bytesize -= 4

        oid = read_i32(io) # unused but in header
        bytesize -= 4

        dim_info = Array({dim: Int32, lbound: Int32}).new(dimensions) do |i|
          bytesize -= 8
          {
            dim:    read_i32(io),
            lbound: read_i32(io),
          }
        end
        extractor = DataExtractor(D).new(io)

        if dimensions == 1 && dim_info.first[:lbound] == 1
          # allow casting down to unnested crystal arrays
          build_simple_array(has_null, extractor, dim_info.first[:dim]).as(A)
        else
          if dim_info.any? { |di| di[:lbound] < 1 }
            io.skip(bytesize)
            raise PG::RuntimeError.new("Only lower-bounds >= 1 are supported")
          end

          # recursively build nested array
          get_element(extractor, dim_info).as(A)
        end
      end

      def type
        A
      end

      def build_simple_array(has_null, extractor, size)
        Array(A).new(size) { extractor.get_next }
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
