require "./wal_message"

module PG::Replication
  struct Message < WALMessage
    # Requires proto_version >= 2
    # getter transaction_id : Int32
    getter flags : Flags
    getter lsn : Int64
    getter prefix : String
    getter content : Bytes

    def initialize(io : IO)
      # @transaction_id = read(io, Int32) # Requires proto_version >= 2
      @flags = Flags.new(read(io, Int8))
      @lsn = read(io, Int64)
      @prefix = read_string(io)
      @content = read_bytes(io)
    end

    @[::Flags]
    enum Flags : Int8
      Transactional
    end
  end
end
