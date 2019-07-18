require "../numeric"

module PG
  module Decoders
    # Generic Array decoder: decodes to a recursive array type
    struct ArrayDecoder(T, D)
      include Decoder

      def initialize(oid : Int32)
        @oids = [oid] of Int32
      end

      def oids : Array(Int32)
        @oids
      end

      def decode(io, bytesize)
        header = Decoders.decode_array_header(io)

        if header.dimensions == 0
          ([] of T).as(T)
        elsif header.dimensions == 1 && header.dim_info.first[:lbound] == 1
          # allow casting down to unnested crystal arrays
          build_simple_array(io, header.dim_info.first[:dim]).as(T)
        else
          if header.dim_info.any? { |di| di[:lbound] < 1 }
            raise PG::RuntimeError.new("Only lower-bounds >= 1 are supported")
          end

          # recursively build nested array
          get_element(io, header.dim_info).as(T)
        end
      end

      def build_simple_array(io, size)
        Array(T).new(size) { get_next(io) }
      end

      def get_element(io, dim_info)
        if dim_info.size == 1
          lbound = dim_info.first[:lbound] - 1 # in lower-bound is not 1
          Array(T).new(dim_info.first[:dim] + lbound) do |i|
            i < lbound ? nil : get_next(io)
          end
        else
          Array(T).new(dim_info.first[:dim]) do |i|
            get_element(io, dim_info[1..-1])
          end
        end
      end

      def get_next(io)
        bytesize = read_i32(io)
        if bytesize == -1
          nil
        else
          D.new.decode(io, bytesize)
        end
      end

      def type
        T
      end
    end

    # Specific array decoder method: decodes to exactly Array(T).
    # Used when invoking, for example `rs.read(Array(Int32))`.
    def self.decode_array(io, bytesize, t : Array(T).class) forall T
      header = decode_array_header(io)

      decoder = array_decoder(T)

      # Check that what we want to decode actually matches the underlying colum type
      unless decoder.oids.includes?(header.oid)
        correct_decoder = Decoders.from_oid(header.oid)

        raise PG::RuntimeError.new("Can't read column of type Array(#{correct_decoder.type}) as Array(#{flatten_type(T)})")
      end

      if header.dimensions == 0
        return [] of T
      end

      decode_array_element(io, t, header.dim_info)
    end

    def self.decode_array_element(io, t : Array(T).class, dim_info) forall T
      size = dim_info.first[:dim]
      rest = dim_info[1..-1]

      Array(T).new(size) do
        decode_array_element(io, T, rest)
      end
    end

    def self.decode_array_element(io, t : T.class, dim_info) forall T
      bytesize = read_i32(io)
      if bytesize == -1
        {% if T.nilable? %}
          nil
        {% else %}
          raise PG::RuntimeError.new("unexpected NULL")
        {% end %}
      else
        array_decoder(t).decode(io, bytesize)
      end
    end

    def self.array_decoder(t : Array(T).class) forall T
      array_decoder(T)
    end

    {% for type in %w(Bool Char Int16 Int32 String Int64 Float32 Float64 Numeric).map(&.id) %}
      def self.array_decoder(t : {{type}}?.class)
        {{type}}Decoder.new
      end

      def self.array_decoder(t : {{type}}.class)
        {{type}}Decoder.new
      end
    {% end %}

    def self.flatten_type(t : Array(T).class) forall T
      flatten_type(T)
    end

    def self.flatten_type(t : T?.class) forall T
      T
    end

    def self.flatten_type(t : T.class) forall T
      T
    end

    record ArrayHeader,
      dimensions : Int32,
      oid : Int32,
      dim_info : Array({dim: Int32, lbound: Int32})

    def self.decode_array_header(io)
      dimensions = read_i32(io)
      has_null = read_i32(io) == 1 # unused
      oid = read_i32(io)           # unused but in header
      dim_info = Array({dim: Int32, lbound: Int32}).new(dimensions) do |i|
        {
          dim:    read_i32(io),
          lbound: read_i32(io),
        }
      end

      ArrayHeader.new(dimensions, oid, dim_info)
    end

    def self.read_i32(io)
      io.read_bytes(Int32, IO::ByteFormat::NetworkEndian)
    end
  end

  macro array_type(t, oid)
    alias {{t}}Array = {{t}}? | Array({{t}}Array)
    module Decoders
      register_decoder ArrayDecoder({{t}}Array, {{t}}Decoder).new({{oid}})
    end
  end

  array_type Bool, 1000
  array_type Char, 1002
  array_type Int16, 1005
  array_type Int32, 1007
  array_type String, 1009
  array_type Int64, 1016
  array_type Float32, 1021
  array_type Float64, 1022
end
