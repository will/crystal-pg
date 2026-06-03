require "./wal_message"

module PG::Replication
  struct Update < WALMessage
    getter oid : Int32
    getter key_tuple_data : TupleData?
    getter old_tuple_data : TupleData?
    getter new_tuple_data : TupleData

    def initialize(io : IO)
      @oid = read(io, Int32)
      submessage_type = read(io, UInt8)
      case submessage_type
      when 'K'
        @key_tuple_data = read_tuple_data(io)
      when 'O'
        @old_tuple_data = read_tuple_data(io)
      when 'N'
        new_tuple_data = read_tuple_data(io)
      end

      # If either 'K' or 'O' were specified above, then the next value is our
      # new tuple. Otherwise, that was our new tuple, so we just assign it.
      if new_tuple_data
        @new_tuple_data = new_tuple_data
      else
        case byte = read(io, UInt8)
        when 'N'
          @new_tuple_data = read_tuple_data(io)
        else
          raise Error.new("Expected new TupleData byte marker, got: 0x#{byte.to_s(16)} (#{byte.chr.inspect})")
        end
      end
    end
  end
end
