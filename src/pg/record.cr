struct PG::Record(*T)
  getter data : T

  def self.read_from(reader : Reader)
    new reader.read({{T.map(&.instance)}})
  end

  def initialize(@data)
  end

  struct Reader
    getter bytes : Bytes
    getter size : Int32
    getter connection : Connection

    def initialize(@bytes, @size, @connection)
    end

    def read(types : Tuple(*T)) forall T
      io = ResultSet::Buffer.new(IO::Memory.new(@bytes), @bytes.size, @connection)

      {% begin %}
        {
          {% for type in T %}
            read({{type}}, io).as({{type.instance}}),
          {% end %}
        }
      {% end %}
    end

    private def read(type : T.class, io : IO) : T forall T
      oid = io.read_bytes(Int32, IO::ByteFormat::BigEndian)
      size = io.read_bytes(Int32, IO::ByteFormat::BigEndian)
      Decoders.from_oid(oid).decode(io, size, oid)
    end
  end
end

class DB::ResultSet
  def read(type : PG::Record.class)
    type.read_from read(PG::Record::Reader)
  end
end
