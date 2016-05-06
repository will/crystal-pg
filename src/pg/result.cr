module PG
  class Result(T)
    getter decoders : Array(PG::Decoders::Decoder)

    def self.stream(types : T, res : PQ::ExtendedQuery)
      r = new(types, res, false)
      r.stream { |row, fields| yield row, fields }
      nil
    end

    def initialize(@types : T, @res : PQ::ExtendedQuery, cache_data = true)
      @decoders = @res.fields.map { |f| PG::Decoders.from_oid(f.type_oid) }
      if cache_data
        @raw_data = Array(Array(Slice(UInt8)?)).new
        @res.get_data { |r| @raw_data << r }
      else
        @raw_data = Array(Array(Slice(UInt8)?)).new
      end
    end

    def rows
      a = [] of typeof(first)
      each(@types) { |r| a << r }
      a
    end

    private def first
      each { |row| return row }
      raise "this should be unreachable"
    end

    def each
      each(@types) { |row| yield row, fields }
    end

    protected def stream
      stream(@types) { |row| yield row, fields }
    end

    private def each(types : Array(PGValue))
      @raw_data.each { |row| yield row.map_with_index { |data, col| decode(data, col) } }
    end

    private def stream(types : Array(PGValue))
      res.get_data { |row| yield row.map_with_index { |data, col| decode(data, col) } }
    end

    macro generate_private_each(from, to)
      {% for n in (from..to) %}
        private def each(types : Tuple({% for i in (1...n) %}Class, {% end %} Class))
          @raw_data.each do |row|
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

    macro generate_private_stream(from, to)
      {% for n in (from..to) %}
        private def stream(types : Tuple({% for i in (1...n) %}Class, {% end %} Class))
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
    generate_private_stream(1, 32)

    def fields
      @res.fields
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

    @[AlwaysInline]
    protected def decode(data, col)
      if data
        decoders[col].decode(data)
      else
        nil
      end
    end
  end
end
