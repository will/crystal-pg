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

    def initialize
      @pq_conn = initialize(PQ::ConnInfo.new)
    end

    def initialize(conninfo : PQ::ConnInfo)
      @pq_conn = PQ::Connection.new(conninfo)
      @pq_conn.connect
    end

    def initialize(conninfo : String)
      initialize PQ::ConnInfo.new(conninfo)
    end

    # `#initialize` Connect to the server with values of Hash.
    #
    #     PG::Connection.new({ "host": "localhost", "user": "postgres",
    #       "password":"password", "db_name": "test_db", "port": "5432" })
    def initialize(params : Hash)
      initialize PQ::ConnInfo.new(params)
    end

    def on_notice(&on_notice_proc : PQ::Notice ->)
      @pq_conn.notice_handler = on_notice_proc
    end

    def finalize
      finish
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
      PQ::SimpleQuery.new(@pq_conn, query)
      nil
    end

    def finish
      # todo close conection
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
      PQ::ExtendedQuery.new(@pq_conn, query, encoded_params)
    end
  end
end
