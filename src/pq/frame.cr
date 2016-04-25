module PQ
  abstract struct Frame
    getter bytes

    def self.new(type : Char, bytes : Slice(UInt8))
      k = case type
          when 'R' then AuthenticationOK
          when 'S' then ParameterStatus
          when 'K' then BackendKeyData
          when 'Z' then ReadyForQuery
          when 'E' then ErrorResponse
          when 'T' then RowDescription
            # when 'D' then DataRow
          when 'C' then CommandComplete
          when '1' then ParseComplete
          when '2' then BindComplete
          end
      k ? k.new(bytes) : Unknown.new(type, bytes)
    end

    def initialize(bytes)
    end

    private def find_next_string(pos, bytes)
      start = pos
      (bytes + start).each do |c|
        break if c == 0
        pos += 1
      end
      return pos + 1, String.new(bytes[start, pos - start])
    end

    private def i32(pos, bytes) : {Int32, Int32}
      return pos + 4, (bytes[pos + 3].to_i32 << 0) |
        (bytes[pos + 2].to_i32 << 8) |
        (bytes[pos + 1].to_i32 << 16) |
        (bytes[pos + 0].to_i32 << 24)
    end

    private def i16(pos, bytes) : {Int32, Int16}
      return pos + 2, (bytes[pos + 1].to_i16 << 0) |
        (bytes[pos + 0].to_i16 << 8)
    end

    struct Unknown
      getter type : Char
      getter bytes : Slice(UInt8)

      def initialize(@type, @bytes)
      end
    end

    struct AuthenticationOK < Frame
    end

    struct ParameterStatus < Frame
      getter key : String
      getter value : String

      def initialize(bytes)
        pos, @key = find_next_string(0, bytes)
        @value = String.new(bytes[pos + 1, bytes.size - pos - 2])
      end
    end

    struct BackendKeyData < Frame
      getter pid : Int32
      getter secret : Int32

      def initialize(bytes)
        pos = 0
        pos, @pid = i32(pos, bytes)
        pos, @secret = i32(pos, bytes)
      end
    end

    struct ReadyForQuery < Frame
      enum Status : UInt8
        Idle        = 0x49 # I
        Transaction = 0x54 # T
        Error       = 0x45 # E
      end

      getter transaction_status : Status

      def initialize(bytes)
        @transaction_status = Status.from_value bytes[0]
      end
    end

    struct ErrorResponse < Frame
      record Field, name : Symbol, message : String, code : UInt8 do
        def inspect(io)
          io << name << ": " << message
        end
      end
      getter fields : Array(Field)

      def initialize(bytes)
        @fields = Array(Field).new
        pos = 0
        loop do
          code = bytes[pos]
          break if code == 0
          pos += 1
          pos, message = find_next_string(pos, bytes)
          @fields << Field.new(name_from_code(code), message, code)
        end
      end

      private def name_from_code(code)
        case code
        when 'S' then :severity
        when 'C' then :code
        when 'M' then :message
        when 'D' then :detail
        when 'H' then :hint
        when 'P' then :position
        when 'p' then :internal_position
        when 'q' then :internal_query
        when 'W' then :where
        when 's' then :schema_name
        when 't' then :table_name
        when 'c' then :column_name
        when 'd' then :datatype_name
        when 'n' then :constraint_name
        when 'F' then :file
        when 'L' then :line
        when 'R' then :routine
        else          :unknown
        end
      end
    end

    struct RowDescription < Frame
      getter nfields : Int16
      getter fields : Array(Field)

      def initialize(bytes)
        pos = 0
        pos, @nfields = i16 pos, bytes
        @fields = Array(Field).new(@nfields.to_i32) do
          pos, name = find_next_string(pos, bytes)
          pos, col_oid = i32 pos, bytes
          pos, table_oid = i16 pos, bytes
          pos, type_oid = i32 pos, bytes
          pos, type_size = i16 pos, bytes
          pos, type_modifier = i32 pos, bytes
          pos, format = i16 pos, bytes
          Field.new(name, col_oid, table_oid, type_oid, type_size, type_modifier, format)
        end
      end
    end

    #  struct DataRow < Frame
    #    def initialize(bytes, &block : Int16, Slice(UInt8) ->)
    #      pos, nrows = i16 0, bytes
    #      nrows.times do |i|
    #        pos, size = i32 pos, bytes
    #        block.call(i, bytes[pos, size])
    #        pos += size
    #      end
    #    end
    #  end

    struct CommandComplete < Frame
    end

    struct ParseComplete < Frame
    end

    struct BindComplete < Frame
    end
  end
end
