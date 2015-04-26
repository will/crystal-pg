module PG
  class Connection
    getter raw

    def initialize(conninfo)
      @raw = LibPQ.connect(conninfo)
    end

    def exec(query)
      LibPQ.exec(raw, query)
    end
  end
end
