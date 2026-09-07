require "./wal_message"

module PG::Replication
  struct Truncate < WALMessage
    # transaction_id requires proto_version >= 2
    # getter transaction_id : Int32
    getter options : Options
    getter relation_oids : Array(Int32)

    def initialize(io : IO)
      # @transaction_id = read(io, Int32) # Requires proto_version >= 2
      relation_count = read(io, Int32)
      @options = Options.new(read(io, Int8))
      @relation_oids = Array.new(relation_count) do
        read(io, Int32)
      end
    end

    @[Flags]
    enum Options : Int8
      NONE             = 0
      CASCADE          = 1
      RESTART_IDENTITY = 2
    end
  end
end
