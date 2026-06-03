require "./wal_message"

module PG::Replication
  struct Insert < WALMessage
    # getter transaction_id : Int32
    getter oid : Int32
    getter tuple_data : TupleData

    def initialize(io : IO)
      # Only included in WAL protocol v2+
      # @transaction_id = read(io, Int32)
      @oid = read(io, Int32)
      # This is an 'N' indicating a new tuple
      io.read_byte
      @tuple_data = read_tuple_data(io)
    end
  end
end
