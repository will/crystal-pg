require "./wal_message"

module PG::Replication
  struct Type < WALMessage
    # getter transaction_id : Int32
    getter oid : Int32
    getter namespace : String
    getter data_type : String

    def initialize(io : IO)
      @oid = read(io, Int32)
      @namespace = read_string(io)
      @data_type = read_string(io)
    end
  end
end
