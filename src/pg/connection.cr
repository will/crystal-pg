require "./error"
module PG
  class Connection
    def initialize(conninfo)
      @raw = LibPQ.connect(conninfo)
      unless LibPQ.status(raw) == LibPQ::ConnStatusType::CONNECTION_OK
        error = ConnectionError.new(@raw)
        finish
        raise error
      end
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
      Result.new(types, libpq_exec(query, params))
    end

    def finish
      LibPQ.finish(raw)
      @raw = nil
    end

    def version
      query = "SELECT ver[1]::int AS major, ver[2]::int AS minor, ver[3]::int AS patch
               FROM regexp_matches(version(), 'PostgreSQL (\\d+)\\.(\\d+)\\.(\\d+)') ver"
      version = exec({Int32, Int32, Int32}, query).rows.first
      {major: version[0], minor: version[1], patch: version[2]}
    end

    private getter raw

    private def libpq_exec(query, params)
      n_params      = params.size
      param_types   = Pointer(LibPQ::Int).null # have server infer types
      param_values  = params.map { |v| simple_encode(v) }
      param_lengths = Pointer(LibPQ::Int).null # only for binary which is not yet supported
      param_formats = Pointer(LibPQ::Int).null # if null, only text is assumed
      result_format = 0 # text vs. binary

      res = LibPQ.exec_params(
        raw           ,
        query         ,
        n_params      ,
        param_types   ,
        param_values  ,
        param_lengths ,
        param_formats ,
        result_format
      )
      check_status(res)
      res
    end


    private def check_status(res)
      status = LibPQ.result_status(res)
      return if ( status == LibPQ::ExecStatusType::PGRES_TUPLES_OK ||
                  status == LibPQ::ExecStatusType::PGRES_SINGLE_TUPLE ||
                  status == LibPQ::ExecStatusType::PGRES_COMMAND_OK )
      error = ResultError.new(res, status)
      Result.clear_res(res)
      raise error
    end

    # The only special case is nil->null.
    # If more types need special cases, there should be an encoder
    private def simple_encode(val)
      if val.nil?
        Pointer(LibPQ::CChar).null
      else
        val.to_s.to_unsafe
      end
    end
  end
end
