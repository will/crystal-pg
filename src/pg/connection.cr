require "../pq/*"
require "./error"

module PG
  class Connection
    # :nodoc:
    record Param, slice : Slice(UInt8), format : Int32 do # Internal wrapper to represent an encoded parameter
      delegate to_unsafe, slice
      delegate size, slice

      # The only special case is nil->null and slice.
      # If more types need special cases, there should be an encoder
      def self.encode(val)
        if val.nil?
          binary Pointer(UInt8).null.to_slice(0)
        elsif val.is_a? Slice
          binary val
        else
          text val.to_s.to_slice
        end
      end

      def self.binary(slice)
        new slice, 1_i16
      end

      def self.text(slice)
        new slice, 0_i16
      end
    end

    def initialize(conninfo : String)
      # @conn_ptr = LibPQ.connect(conninfo)
      # unless LibPQ.status(conn_ptr) == LibPQ::ConnStatusType::CONNECTION_OK
      #  error = ConnectionError.new(@conn_ptr)
      #  finish
      #  raise error
      # end

      # setup_notice_processor
      @pq_conn = PQ::Connection.new
      @pq_conn.connect
    end

    def on_notice(&on_notice_proc : String -> Void)
      @on_notice_proc = on_notice_proc
    end

    protected def process_notice(msg : String)
      if on_notice_proc = @on_notice_proc
        on_notice_proc.call msg
      end
    end

    private def setup_notice_processor
      notice_processor = ->(pCrystalConnection : Void*, message : Pointer(LibPQ::CChar)) {
        crystal_connection = pCrystalConnection as PG::Connection

        crystal_connection.process_notice(String.new(message))
        nil
      }
      LibPQ.set_notice_processor(conn_ptr, notice_processor, self as Void*)
    end

    def finalize
      finish
    end

    # `#initialize` Connect to the server with values of Hash.
    #
    #     PG::Connection.new({ "host": "localhost", "user": "postgres",
    #       "password":"password", "db_name": "test_db", "port": "5432" })
    def initialize(parameters : Hash)
      initialize(parameters.map { |param, value| "#{param}=#{value}" }.join(" "))
    end

    def exec(query : String)
      exec([] of PG::PGValue, query, [] of PG::PGValue)
    end

    def exec(query : String, params)
      exec([] of PG::PGValue, query, params)
    end

    def exec(types, query : String)
      exec(types, query, [] of PG::PGValue)
    end

    def exec(types, query : String, params)
      Result.new(types, extended_query(query, params))
    end

    def exec_all(query : String)
      # todo simple query
    end

    def finish
      # todo close conection
      @conn_ptr = nil
    end

    def version
      query = "SELECT ver[1]::int AS major, ver[2]::int AS minor, ver[3]::int AS patch
               FROM regexp_matches(version(), 'PostgreSQL (\\d+)\\.(\\d+)\\.(\\d+)') ver"
      version = exec({Int32, Int32, Int32}, query).rows.first
      {major: version[0], minor: version[1], patch: version[2]}
    end

    # `#escape_literal` escapes a string for use within an SQL command. This is
    # useful when inserting data values as literal constants in SQL commands.
    # Certain characters (such as quotes and backslashes) must be escaped to
    # prevent them from being interpreted specially by the SQL parser.
    # PQescapeLiteral performs this operation.
    #
    # Note that it is not necessary nor correct to do escaping when a data
    # value is passed as a separate parameter in `#exec`
    def escape_literal(str)
      # todo reimpliment
    end

    # `#escape_literal` escapes binary data suitable for use with the BYTEA type.
    def escape_literal(slice : Slice(UInt8))
      ssize = slice.size * 2 + 4
      String.new(ssize) do |buffer|
        buffer[0] = '\''.ord.to_u8
        buffer[1] = '\\'.ord.to_u8
        buffer[2] = 'x'.ord.to_u8
        slice.hexstring(buffer + 3)
        buffer[ssize - 1] = '\''.ord.to_u8
        {ssize, ssize}
      end
    end

    # `#escape_identifier` escapes a string for use as an SQL identifier, such
    # as a table, column, or function name. This is useful when a user-supplied
    # identifier might contain special characters that would otherwise not be
    # interpreted as part of the identifier by the SQL parser, or when the
    # identifier might contain upper case characters whose case should be
    # preserved.
    def escape_identifier(str)
      # todo reimpliment
    end

    private getter conn_ptr

    def extended_query(query, params)
      encoded_params = params.map { |v| Param.encode(v) }
      eq = PQ::ExtendedQuery.new(@pq_conn, query, encoded_params)
      return eq
    end
  end
end
