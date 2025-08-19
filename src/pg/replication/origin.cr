require "./wal_message"

module PG::Replication
  struct Origin < WALMessage
    getter lsn : Int64
    getter name : String

    def initialize(io : IO)
      @lsn = read(io, Int64)
      @name = read_string(io)
    end
  end
end
