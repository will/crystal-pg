require "../pg/interval"
require "../pg/geo"

module PQ
  # :nodoc:
  record Param, slice : Slice(UInt8), size : Int32, format : Format do
    enum Format : Int16
      Text   =  0
      Binary =  1
    end
    delegate to_unsafe, to: slice

    #  Internal wrapper to represent an encoded parameter

    def self.encode(val : Nil)
      encode val, into: Bytes.empty
    end

    def self.encode(val : Nil, into slice : Bytes)
      binary slice, -1
    end

    def self.encode(val : Bool, into slice : Bytes = Bytes.new(1))
      slice[0] = val ? 1u8 : 0u8
      binary slice
    end

    def self.encode(val : String)
      encode val.to_slice
    end

    def self.encode(val : String, into slice : Bytes)
      encode val.to_slice, into: slice
    end

    def self.encode(val : Slice)
      binary val
    end

    def self.encode(val : Slice, into slice : Bytes)
      val.copy_to slice

      binary slice
    end

    def self.encode(val : Array(T)) forall T
      bytes = ArrayEncoder.new(val).to_slice

      binary bytes
    end

    def self.encode(val : Time)
      # text Time::Format::RFC_3339.format(val, fraction_digits: 9)
      encode ((val - 30.years).to_unix_ns // 1_000).to_i64
    end

    {% for type in %w[Int16 Int32 Int64 Float32 Float64] %}
      def self.encode(val : {{type.id}}, into slice : Bytes = Bytes.new(sizeof(typeof(val))))
        IO::ByteFormat::NetworkEndian.encode val, slice
        binary slice
      end
    {% end %}

    def self.encode(val : Enum)
      encode val.value
    end

    def self.encode(val : UUID)
      bytes = Bytes.new(16)
      val.bytes.to_slice.copy_to bytes
      binary bytes
    end

    def self.encode(val : PG::Geo::Point, into slice : Bytes = Bytes.new(sizeof(PG::Geo::Point)))
      encode val.x, into: slice
      encode val.y, into: slice + sizeof(Float64)

      binary slice
    end

    def self.encode(val : PG::Geo::Line)
      slice = Bytes.new(sizeof(PG::Geo::Line))
      encode val.a, into: slice
      encode val.b, into: slice + sizeof(Float64)
      encode val.c, into: slice + sizeof(Float64) * 2

      binary slice
    end

    def self.encode(val : PG::Geo::Circle)
      slice = Bytes.new(sizeof(PG::Geo::Circle))
      encode val.x, into: slice
      encode val.y, into: slice + sizeof(Float64)
      encode val.radius, into: slice + sizeof(Float64) * 2

      binary slice
    end

    def self.encode(val : PG::Geo::LineSegment | PG::Geo::Box)
      slice = Bytes.new(sizeof(PG::Geo::LineSegment))
      encode val.x1, into: slice
      encode val.y1, into: slice + sizeof(Float64)
      encode val.x2, into: slice + sizeof(Float64) * 2
      encode val.y2, into: slice + sizeof(Float64) * 3

      binary slice
    end

    def self.encode(val : PG::Geo::Path)
      slice = Bytes.new(
        sizeof(UInt8) +                            # closed flag
        sizeof(UInt32) +                           # Size
        sizeof(PG::Geo::Point) * val.points.size + # point data
        0
      )

      slice[0] = val.closed? ? 1u8 : 0u8

      encode_points(val, into: slice + 1)
      binary slice
    end

    def self.encode(val : PG::Geo::Polygon)
      slice = Bytes.new(
        sizeof(UInt32) +                           # Size
        sizeof(PG::Geo::Point) * val.points.size + # point data
        0
      )

      encode_points val, into: slice
    end

    private def self.encode_points(val, into slice : Bytes)
      encode val.points.size, into: slice
      data = slice + sizeof(UInt32)
      val.points.each_with_index do |point, index|
        encode point, into: data + index * sizeof(PG::Geo::Point)
      end

      binary slice
    end

    def self.encode(val : PG::Interval)
      slice = Bytes.new(sizeof(PG::Interval))

      encode val.microseconds, into: slice
      encode val.days, into: slice + sizeof(Int64)
      encode val.months, into: slice + sizeof(Int64) + sizeof(Int32)

      binary slice
    end

    def self.binary(slice, size = slice.bytesize)
      new slice, size, :binary
    end

    # Types taken from src/pg/decoder.cr
    private OID_MAP = {
      Bool.name                 => 16,   # boolean
      Bytes.name                => 17,   # bytea
      Char.name                 => 18,   # char
      Int16.name                => 21,   # int2
      Int32.name                => 23,   # int4
      Int64.name                => 20,   # int8
      String.name               => 25,   # text
      Float32.name              => 700,  # float4
      Float64.name              => 701,  # float8
      UUID.name                 => 2950, # uuid
      PG::Geo::Point.name       => 600,  # point
      PG::Geo::Path.name        => 602,  # path
      PG::Geo::Polygon.name     => 604,  # polygon
      PG::Geo::Box.name         => 603,  # box
      PG::Geo::LineSegment.name => 601,  # lseg
      PG::Geo::Line.name        => 628,  # line
      PG::Geo::Circle.name      => 718,  # circle
      JSON::Any.name            => 3802, # jsonb
      Time.name                 => 1184, # timestamptz
      Time::Span.name           => 1186, # interval
      PG::Interval.name         => 1186, # interval
    } of String => Int32

    protected def self.oid_for(type : T.class) forall T
      {% if T.union? %}
        oid_for({{T.union_types.reject(&.nilable?).first}})
      {% else %}
        OID_MAP[type.name]
      {% end %}
    end

    protected def self.oid_for(type : Array(T).class) forall T
      oid_for(T)
    end

    record ArrayEncoder(T), array : Array(T) do
      # Count array dimensions at compile time. This will generate an arithmetic
      # expression like `1 + 1 + 1 + 0` for a 3-dimensional array, which will be
      # inlined into the numeric literal `3` at compile time.
      macro dimension_count(type)
        {% if type.is_a? Expressions %}
          ::PQ::Param::ArrayEncoder.dimension_count(Union({{type}}))
        {% elsif type.resolve < Array %}
          1 + dimension_count({{type.resolve.type_vars.first}})
        {% else %}
          0
        {% end %}
      end

      def to_slice
        # puts
        dimensions = dimension_count(Array(T))
        nilable = {{T.nilable?}}
        oid = Param.oid_for(T)
        flat_data = array.flatten # TODO: Avoid allocating this
        data_size = total_element_count * 4 + flat_data.sum { |element| size_for(element) }
        # pp total_element_count: total_element_count

        bytes = Bytes.new(
          4 +              # dimension count
          4 +              # nulls flag (why is this 32-bit?)
          4 +              # element OID
          8 * dimensions + # dimension length and lower bound
          data_size +      # 32-bit size prefix
          0
        )
        format = IO::ByteFormat::NetworkEndian
        format.encode dimensions, bytes
        format.encode nilable ? 1 : 0, bytes + 4
        format.encode oid, bytes + 8

        dimensions_offset = 12
        collect_dimensions.each_with_index do |size, index|
          entry_offset = dimensions_offset + 8 * index
          format.encode size, bytes + entry_offset
          format.encode 1, bytes + entry_offset + 4
        end

        # pp collect_dimensions: collect_dimensions, data_size: {
        #   from_size_prefixes: total_element_count * 4,
        #   from_data: flat_data.sum { |e| size_for e },
        #   total: data_size,
        #   }
        data_offset = dimensions_offset + 8 * collect_dimensions.size
        flat_data.each do |element|
          # pp encoding: element, into: data_offset
          if element.nil?
            size = -1
          else
            size = size_for(element)
          end
          Param.encode size, into: bytes + data_offset
          Param.encode element, into: bytes + data_offset + 4
          data_offset += size + 4
        end

        # pp bytes.to_a.map_with_index { |byte, index| {index, byte.chr} }.to_h

        bytes
      end

      private SIZE_MAP = {
        Bool.name    => 1,
        Int16.name   => sizeof(Int16),
        Int32.name   => sizeof(Int32),
        Int64.name   => sizeof(Int64),
        Float64.name => sizeof(Float64),
        UUID.name    => sizeof(UUID),
      }

      def size_for(value : T) forall T
        {% if T.union? %}
          if value.nil?
            0
          else
            size_for(value.as({{T.union_types.reject(&.nilable?).first}}))
          end
        {% else %}
          SIZE_MAP.fetch(value.class.name) do
            raise "Could not determine encoding size for #{T}"
          end
        {% end %}
      end

      def size_for(value : Bool)
        1
      end

      def size_for(data : String | Bytes)
        data.bytesize
      end

      def total_element_count(value : Array = array)
        value.sum { |element| total_element_count(element) }
      end

      def total_element_count(value)
        1
      end

      getter collect_dimensions : Array(Int32) do
        dimensions = Array(Int32).new(dimension_count(Array(T)))
        dimensions << array.size
        dimension = array

        while dimension = dimension.first?.try &.as?(Array)
          dimensions << dimension.size
        end

        dimensions
      end
    end
  end
end
