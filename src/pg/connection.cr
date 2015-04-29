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
      Result.new(LibPQ.exec(raw, query))
    end

    def finish
      LibPQ.finish(raw)
      @raw = nil
    end

    private getter raw
  end
end
