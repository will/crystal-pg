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
      res = LibPQ.exec(raw, query)
      status = LibPQ.result_status(res)
      unless status == LibPQ::ExecStatusType::PGRES_TUPLES_OK || status == LibPQ::ExecStatusType::PGRES_SINGLE_TUPLE
        error = ResultError.new(res, status)
        Result.clear_res(res)
        raise error
      end
      Result.new(res)
    end

    def finish
      LibPQ.finish(raw)
      @raw = nil
    end

    private getter raw
  end
end
