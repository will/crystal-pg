require "./wal_message"

module PG::Replication
  struct Delete < WALMessage
    # getter transaction_id : Int32
    getter oid : Int32
    getter key_tuple_data : TupleData?
    getter old_tuple_data : TupleData?

    def initialize(io : IO)
      # @transaction_id = read(io, Int32) # Requires proto_version >= 2
      @oid = read(io, Int32)
      case byte = io.read_byte
      when nil
        raise IO::EOFError.new("Connection was unexpectedly terminated")
      when 'K'
        @key_tuple_data = read_tuple_data(io)
      when 'O'
        @old_tuple_data = read_tuple_data(io)
      else
        raise Error.new("Expected new TupleData byte marker, got: 0x#{byte.to_s(16)} (#{byte.chr.inspect})")
      end
    end
  end
end
