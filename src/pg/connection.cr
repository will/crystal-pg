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

    def exec(query)
      exec(query, [] of PG::PGValue)
    end

    def exec(query, params)
      #res = LibPQ.exec(raw, query)
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
      Result.new(res)
    end

    def finish
      LibPQ.finish(raw)
      @raw = nil
    end

    def version
      query = "SELECT ver[1] AS major, ver[2] AS minor, ver[3] AS patch
               FROM regexp_matches(version(), 'PostgreSQL (\\d+)\\.(\\d+)\\.(\\d+)') ver"
      version = exec(query).rows.first
      major = version[0].to_s.to_i
      minor = version[1].to_s.to_i
      patch = version[2].to_s.to_i
     {:major => major, :minor => minor, :patch => patch}
    end

    private getter raw

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
