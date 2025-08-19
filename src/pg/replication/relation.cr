require "./wal_message"

module PG::Replication
  struct Relation < WALMessage
    # Requires proto_version >= 2
    # getter transaction_id : Int32
    getter oid : Int32
    getter namespace : String
    getter name : String
    getter replica_identity : Int8
    getter columns : Array(Column)

    def initialize(io : IO)
      # @transaction_id = read(io, Int32)
      @oid = read(io, Int32)
      @namespace = read_string(io)
      @name = read_string(io)
      @replica_identity = read(io, Int8)
      column_count = read(io, Int16)
      @columns = Array.new(column_count) do
        Column.new(
          flags: Flags.new(read(io, Int8)),
          name: read_string(io),
          oid: read(io, Int32),
          type_modifier: read(io, Int32),
        )
      end
    end

    record Column,
      flags : Flags,
      name : String,
      oid : Int32,
      type_modifier : Int32
    @[::Flags]
    enum Flags
      Key = 1
    end
  end
end
