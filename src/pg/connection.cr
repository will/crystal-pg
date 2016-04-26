require "../pq/*"
require "./error"

module PG
  class Connection
    # :nodoc:
    record Param, slice : Slice(UInt8), size : Int32, format : Int16 do # Internal wrapper to represent an encoded parameter
      delegate to_unsafe, slice

      # The only special case is nil->null and slice.
      # If more types need special cases, there should be an encoder
      def self.encode(val)
        if val.nil?
          binary Pointer(UInt8).null.to_slice(0), -1
        elsif val.is_a? Slice
          binary val, val.size
        else
          text val.to_s.to_slice
        end
      end

      def self.binary(slice, size)
        new slice, size, 1_i16
      end

      def self.text(slice)
        new slice, slice.size, 0_i16
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

    private getter conn_ptr

    def extended_query(query, params)
      encoded_params = params.map { |v| Param.encode(v) }
      eq = PQ::ExtendedQuery.new(@pq_conn, query, encoded_params)
      return eq
    end
  end
end
