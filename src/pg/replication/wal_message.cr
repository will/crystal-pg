require "./read"

module PG::Replication
  abstract struct WALMessage
    include Read

    def self.new(io : IO) : self
      {% if @type != PG::Replication::WALMessage %}
        {% raise "Must implement #{@type}#initialize(io : IO)" %}
      {% end %}

      case byte = io.read_byte
      when Nil
        raise IO::EOFError.new("Connection was unexpectedly terminated")
      when 'B'
        Begin.new(io)
      when 'C'
        Commit.new(io)
      when 'R'
        Relation.new(io)
      when 'I'
        Insert.new(io)
      when 'U'
        Update.new(io)
      when 'D'
        Delete.new(io)
      when 'T'
        Truncate.new(io)
      when 'Y'
        Type.new(io)
      when 'M'
        Message.new(io)
      when 'O'
        Origin.new(io)
      else
        raise Error.new("Unexpected WAL message byte marker: 0x#{byte.to_s(16)} (#{byte.chr.inspect})")
      end
    end

    protected def read_tuple_data(io) : TupleData
      column_count = read(io, Int16)
      Array.new(column_count) do
        case byte = io.read_byte
        when Nil
          raise IO::EOFError.new("Connection was unexpectedly terminated")
        when 'n'
          nil
        when 'u'
          UnchangedTOASTValue.new
        when 't'
          read_string(io)
        when 'b'
          read_bytes(io)
        else
          raise Error.new("Unexpected TupleData byte marker: 0x#{byte.to_s(16)} (#{byte.chr.inspect})")
        end
      end
    end

    alias TupleData = Array(UnchangedTOASTValue | Bytes | String | Nil)
    record UnchangedTOASTValue
  end
end

require "./begin"
require "./commit"
require "./relation"
require "./insert"
require "./update"
require "./delete"
require "./truncate"
require "./type"
require "./message"
require "./origin"
