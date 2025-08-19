require "./wal_message"

module PG::Replication
  struct Commit < WALMessage
    getter flags : Int8
    getter begin_lsn : Int64
    getter end_lsn : Int64
    getter timestamp : Time

    def initialize(io : IO)
      @flags = read(io, Int8)
      @begin_lsn = read(io, Int64)
      @end_lsn = read(io, Int64)
      @timestamp = read_time(io)
    end
  end
end
