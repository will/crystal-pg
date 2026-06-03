require "./time_parser"

module PG::Replication
  module Read
    protected def read(io : IO, int : Int.class)
      io.read_bytes int, IO::ByteFormat::NetworkEndian
    end

    protected def read_string(io : IO) : String
      io.read_line('\0', chomp: true)
    end

    protected def read_bytes(io : IO) : Bytes
      bytes = Bytes.new(read(io, Int32))
      io.read_fully bytes
      bytes
    end

    protected def read_time(io : IO) : Time
      TimeParser.call(io)
    end
  end
end
