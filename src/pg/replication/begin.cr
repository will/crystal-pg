require "./wal_message"
require "./time_parser"

module PG::Replication
  struct Begin < WALMessage
    getter final_lsn : Int64
    getter timestamp : Time
    getter transaction_id : Int32

    def initialize(io : IO)
      @final_lsn = read(io, Int64)
      @timestamp = TimeParser.call(io)
      @transaction_id = read(io, Int32)
    end
  end
end
