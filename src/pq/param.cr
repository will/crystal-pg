require "../pg/geo"
require "../pg/range"

module PQ
  # :nodoc:
  record Param, slice : Slice(UInt8), size : Int32, format : Int16 do
    delegate to_unsafe, to: slice

    #  Internal wrapper to represent an encoded parameter

    def self.encode(val : Nil)
      binary Pointer(UInt8).null.to_slice(0), -1
    end

    def self.encode(val : Slice)
      binary val, val.size
    end

    def self.encode(val : Array)
      text encode_array(val)
    end

    def self.encode(val : Time)
      text format_time(val)
    end

    def self.encode(val : Enum)
      encode val.value
    end

    def self.encode(val : PG::Geo::Point)
      text "(#{val.x},#{val.y})"
    end

    def self.encode(val : PG::Geo::Line)
      text "{#{val.a},#{val.b},#{val.c}}"
    end

    def self.encode(val : PG::Geo::Circle)
      text "<(#{val.x},#{val.y}),#{val.radius}>"
    end

    def self.encode(val : PG::Geo::LineSegment)
      text "((#{val.x1},#{val.y1}),(#{val.x2},#{val.y2}))"
    end

    def self.encode(val : PG::Geo::Box)
      text "((#{val.x1},#{val.y1}),(#{val.x2},#{val.y2}))"
    end

    def self.encode(val : PG::Geo::Path)
      if val.closed?
        encode_points "(", val.points, ")"
      else
        encode_points "[", val.points, "]"
      end
    end

    def self.encode(val : PG::Geo::Polygon)
      encode_points "(", val.points, ")"
    end

    private def self.encode_points(left, points, right)
      string = String.build do |io|
        io << left
        points.each_with_index do |point, i|
          io << "," if i > 0
          io << "(" << point.x << "," << point.y << ")"
        end
        io << right
      end

      text string
    end

    def self.encode(val : PG::Interval)
      # https://www.postgresql.org/docs/current/datatype-datetime.html#DATATYPE-INTERVAL-INPUT
      text "#{val.months} months #{val.days} days #{val.microseconds} microseconds"
    end

    private def self.format_time(value : Time)
      value.to_rfc3339(fraction_digits: 9)
    end

    private def self.range_empty?(range : PG::Range)
      range.empty?
    end

    private def self.range_empty?(range : Range)
      range.begin == range.end && range.excludes_end?
    end

    private def self.start_bracket(range : PG::Range)
      range.lower_inclusive ? "[" : "("
    end

    private def self.start_bracket(range : Range)
      "["
    end

    private def self.format_numeric_range(range)
      if range_empty?(range)
        "empty"
      else
        start_bracket = start_bracket(range)
        end_bracket = range.excludes_end? ? ")" : "]"

        begin_str = range.begin.nil? ? "" : range.begin.to_s
        end_str = range.end.nil? ? "" : range.end.to_s

        "#{start_bracket}#{begin_str},#{end_str}#{end_bracket}"
      end
    end

    private def self.format_timestamp_range(range)
      if range_empty?(range)
        "empty"
      else
        start_bracket = start_bracket(range)
        end_bracket = range.excludes_end? ? ")" : "]"

        begin_str = range.begin.try { |val| format_time(val) } || ""
        end_str = range.end.try { |val| format_time(val) } || ""

        "#{start_bracket}#{begin_str},#{end_str}#{end_bracket}"
      end
    end

    def self.encode(val : Range(Int32?, Int32?))
      text format_numeric_range(val)
    end

    def self.encode(val : Range(Int64?, Int64?))
      text format_numeric_range(val)
    end

    def self.encode(val : Range(PG::Numeric?, PG::Numeric?))
      text format_numeric_range(val)
    end

    def self.encode(val : Range(Time?, Time?))
      text format_timestamp_range(val)
    end

    def self.encode(val : PG::Range(Int32))
      text format_numeric_range(val)
    end

    def self.encode(val : PG::Range(Int64))
      text format_numeric_range(val)
    end

    def self.encode(val : PG::Range(PG::Numeric))
      text format_numeric_range(val)
    end

    def self.encode(val : PG::Range(Time))
      text format_timestamp_range(val)
    end

    private def self.format_multirange(val, &)
      if val.empty?
        "{}"
      else
        range_strs = val.map { |range| yield range }
        "{#{range_strs.join(",")}}"
      end
    end

    def self.encode(val : Array(Range(Int32?, Int32?)))
      text format_multirange(val) { |range| format_numeric_range(range) }
    end

    def self.encode(val : Array(Range(Int64?, Int64?)))
      text format_multirange(val) { |range| format_numeric_range(range) }
    end

    def self.encode(val : Array(Range(PG::Numeric?, PG::Numeric?)))
      text format_multirange(val) { |range| format_numeric_range(range) }
    end

    def self.encode(val : Array(Range(Time?, Time?)))
      text format_multirange(val) { |range| format_timestamp_range(range) }
    end

    def self.encode(val : Array(PG::Range(Int32)))
      text format_multirange(val) { |range| format_numeric_range(range) }
    end

    def self.encode(val : Array(PG::Range(Int64)))
      text format_multirange(val) { |range| format_numeric_range(range) }
    end

    def self.encode(val : Array(PG::Range(PG::Numeric)))
      text format_multirange(val) { |range| format_numeric_range(range) }
    end

    def self.encode(val : Array(PG::Range(Time)))
      text format_multirange(val) { |range| format_timestamp_range(range) }
    end

    def self.encode(val)
      text val.to_s
    end

    def self.binary(slice, size)
      new slice, size, 1_i16
    end

    def self.text(string : String)
      text string.to_slice
    end

    def self.text(slice : Bytes)
      new slice, slice.size, 0_i16
    end

    def self.encode_array(array)
      String.build(array.size + 2) do |io|
        encode_array(io, array)
      end
    end

    def self.encode_array(io, value : Array)
      io << "{"
      value.join(io, ",") do |item|
        encode_array(io, item)
      end

      io << "}"
    end

    def self.encode_array(io, value)
      io << value
    end

    def self.encode_array(io, value : Nil)
      io << "NULL"
    end

    def self.encode_array(io, value : Bool)
      io << (value ? 't' : 'f')
    end

    def self.encode_array(io, value : Bytes)
      io << %{"\\\\x}
      value.each do |byte|
        byte.to_s io, base: 16, precision: 2
      end
      io << '"'
    end

    def self.encode_array(io, value : String)
      io << '"'
      if value.ascii_only?
        special_chars = {'"'.ord.to_u8, '\\'.ord.to_u8}
        last_index = 0
        value.to_slice.each_with_index do |byte, index|
          if special_chars.includes?(byte)
            io.write value.unsafe_byte_slice(last_index, index - last_index)
            last_index = index
            io << '\\'
          end
        end

        io.write value.unsafe_byte_slice(last_index)
      else
        last_index = 0
        reader = Char::Reader.new(value)
        while reader.has_next?
          char = reader.current_char
          if {'"', '\\'}.includes?(char)
            io.write value.unsafe_byte_slice(last_index, reader.pos - last_index)
            last_index = reader.pos
            io << '\\'
          end
          reader.next_char
        end

        io.write value.unsafe_byte_slice(last_index)
      end

      io << '"'
    end
  end
end
