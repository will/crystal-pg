require "../pq/*"
require "./error"

module PG
  class Connection
    def initialize
      initialize(PQ::ConnInfo.new)
    end

    def initialize(conninfo : PQ::ConnInfo)
      @pq_conn = PQ::Connection.new(conninfo)
      @pq_conn.connect
    end

    def initialize(conninfo : String)
      initialize PQ::ConnInfo.from_conninfo_string(conninfo)
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

    def exec(query : String) : Result
      exec([] of PG::PGValue, query, [] of PG::PGValue)
    end

    def exec(query : String, params) : Result
      exec([] of PG::PGValue, query, params)
    end

    def exec(types, query : String) : Result
      exec(types, query, [] of PG::PGValue)
    end

    def exec(types, query : String, params) : Result
      Result.new(types, extended_query(query, params))
    end

    def exec(query : String) : Nil
      exec([] of PG::PGValue, query, [] of PG::PGValue) do |row, fields|
        yield row, fields
      end
    end

    def exec(query : String, params) : Nil
      exec([] of PG::PGValue, query, params) do |row, fields|
        yield row, fields
      end
    end

    def exec(types, query : String) : Nil
      exec(types, query, [] of PG::PGValue) do |row, fields|
        yield row, fields
      end
    end

    def exec(types, query : String, params) : Nil
      Result.stream(types, extended_query(query, params)) do |row, fields|
        yield row, fields
      end
    end

    def exec_all(query : String) : Nil
      PQ::SimpleQuery.new(@pq_conn, query)
      nil
    end

    def finalize
      finish
    end

    def finish
      @pq_conn.close
    end

    def version
      query = "SELECT ver[1]::int AS major, ver[2]::int AS minor, ver[3]::int AS patch
               FROM regexp_matches(version(), 'PostgreSQL (\\d+)\\.(\\d+)\\.(\\d+)') ver"
      version = exec({Int32, Int32, Int32}, query).rows.first
      {major: version[0], minor: version[1], patch: version[2]}
    end

    private def extended_query(query, params)
      PQ::ExtendedQuery.new(@pq_conn, query, params)
    end
  end
end
