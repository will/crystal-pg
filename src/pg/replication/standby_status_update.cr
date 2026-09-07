require "./keep_alive_response"

module PG::Replication
  struct StandbyStatusUpdate < KeepAliveResponse
    getter last_wal_byte_received : Int64
    getter last_wal_byte_flushed : Int64
    getter last_wal_byte_applied : Int64
    getter timestamp : Time
    getter? response_expected : Bool

    def initialize(
      @last_wal_byte_received,
      @last_wal_byte_flushed,
      @last_wal_byte_applied,
      *,
      @timestamp = Time.utc,
      @response_expected = false,
    )
    end

    def to_io(io : IO) : Nil
      io << 'r'
      write io, last_wal_byte_received
      write io, last_wal_byte_flushed
      write io, last_wal_byte_applied
      write io, (@timestamp - Time.utc(2000, 1, 1)).total_microseconds.to_i64
      write io, response_expected? ? 1u8 : 0u8
    end

    private def write(io, value)
      io.write_bytes value, IO::ByteFormat::NetworkEndian
    end
  end
end
