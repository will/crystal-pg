module PG
  class Result(T)
    struct Row(T)
      def initialize(@result : PG::Result(T), @row : Int32)
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
        new(
          String.new(LibPQ.fname(res, col)),
          LibPQ.ftype(res, col)
        )
      end

      def decoder
        PG::Decoder.from_oid(oid)
      end
    end

    def initialize(@types : T, @res : LibPQ::PGresult)
    end

    def finalize
      LibPQ.clear(res)
    end

    def each
      ntuples.times { |i| yield Row.new(self, i) }
    end

    def fields
      Array.new(nfields) do |i|
        Field.new_from_res(res, i)
      end
    end

    def rows
      gather_rows(@types)
    end

    def any?
      ntuples > 0
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

    private def ntuples
      LibPQ.ntuples(res)
    end

    private def nfields
      LibPQ.nfields(res)
    end

    private def gather_rows(types : Array(PGValue))
      Array.new(ntuples) do |i|
        Array.new(nfields) do |j|
          decode_value(i, j)
        end
      end
    end

    macro generate_gather_rows(from, to)
      {% for n in (from..to) %}
        private def gather_rows(types : Tuple({% for i in (1...n) %}Class, {% end %} Class))
          Array.new(ntuples) do |i|
            { {% for j in (0...n) %} types[{{j}}].cast( decode_value(i, {{j}}) ), {% end %} }
          end
        end
      {% end %}
    end

    generate_gather_rows(1, 32)

    protected def decode_value(row, col)
      val_ptr = LibPQ.getvalue(res, row, col)
      if val_ptr.value == 0 && LibPQ.getisnull(res, row, col)
        nil
      else
        size = LibPQ.getlength(res, row, col)
        fields[col].decoder.decode(val_ptr.to_slice(size))
      end
    end
  end
end
