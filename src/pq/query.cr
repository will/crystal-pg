module PQ
  # :nodoc:
  struct ExtendedQuery
    getter conn, query, params

    def self.new(conn, query, params)
      encoded_params = params.map { |v| Param.encode(v).as(Param) }
      new(conn, query, encoded_params.to_a)
    end

    def initialize(@conn : Connection, @query : String, @params : Array(Param))
    end

    def exec
      send
      # TODO: How should we process the result? SHOULD we process it here?
    end

    def send
      conn.send_parse_message query
      conn.send_bind_message params
      conn.send_describe_portal_message
      conn.send_execute_message
      conn.send_sync_message
    end
  end

  # :nodoc:
  struct SimpleQuery
    getter conn, query

    def initialize(@conn : Connection, @query : String)
    end

    def exec
      conn.send_query_message(query)

      while !conn.read.is_a?(Frame::ReadyForQuery)
      end

      nil
    end
  end
end
