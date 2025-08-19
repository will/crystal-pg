require "./time_parser"

module PG::Replication
  struct KeepAlive
    getter wal_end : Int64
    getter timestamp : Time
    getter? response_expected : Bool

    def initialize(io : IO)
      @wal_end = io.read_bytes(Int64, IO::ByteFormat::NetworkEndian)
      @timestamp = TimeParser.call(io)
      @response_expected = io.read_bytes(Int8, IO::ByteFormat::NetworkEndian) == 1
    end

    def to_io(io : IO) : Nil
      raise NotImplementedError.new("KeepAlives are intended to be received from the server, not sent to it")
    end
  end
end
