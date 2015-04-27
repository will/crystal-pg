module PG
  class Connection
    getter raw

    def initialize(conninfo)
      @raw = LibPQ.connect(conninfo)
    end

    def exec(query)
      Result.new(LibPQ.exec(raw, query))
    end
  end
end
