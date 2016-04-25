module PG
  class Result(T)
    struct Row
      def initialize(@result, @row)
      end

      def each
        @result.fields.each_with_index do |field, col|
          yield field.name, @result.decode_value(@row, col)
        end
      end
    end

    struct Field
      property name
      property oid

      def initialize(@name : String, @oid : Int32)
      end

      def self.new_from_res(res, col)
        f = res.fields[col]
        new(f.name, f.type_oid)
      end

      def decoder
        PG::Decoder.from_oid(oid)
      end
    end

    def initialize(@types : T, @res : LibPQ::PGresult)
    end

    def rows
      a = [first]
      each(@types) { |r| a << r }
      a
    end

    private def first
      each { |row| return row }
      raise "this should be unreachable"
    end

    def each
      each(@types) { |row| yield row }
    end

    private def each(types : Array(PGValue))
      res.get_data { |row| yield row.map_with_index { |data, col| decode(data, col) } }
    end

    macro generate_private_each(from, to)
      {% for n in (from..to) %}
        private def each(types : Tuple({% for i in (1...n) %}Class, {% end %} Class))
          res.get_data do |row|
            yield ({
              {% for j in (0...n) %}
                types[{{j}}].cast(
                  decode( row[{{j}}], {{j}}) ),
              {% end %}
            })
          end
        end
      {% end %}
    end

    generate_private_each(1, 32)

    def fields
      @fields ||= Array.new(nfields) do |i|
        Field.new_from_res(res, i)
      end
    end

    def to_hash
      field_names = fields.map(&.name)

      if field_names.uniq.size != field_names.size
        raise PG::RuntimeError.new("Duplicate field names in result set")
      end

      rows.map do |row|
        Hash.zip(field_names, row.to_a)
      end
    end

    private getter res

    private def nfields
      res.fields.size
    end

    protected def decode(data, col)
      if data
        fields[col].decoder.decode(data)
      else
        nil
      end
    end
  end
end
