module PG::Replication
  private module TimeParser
    extend self

    def call(io : IO) : Time
      call io.read_bytes(Int64, IO::ByteFormat::NetworkEndian)
    end

    def call(microseconds : Int64)
      Time.utc(2000, 1, 1) + microseconds.microseconds
    end
  end
end
