module PQ
  class ExtendedQuery
    getter conn, query, params, fields

    def initialize(@conn : Connection, @query : String, @params : Array(PG::Connection::Param))
      conn.send_parse_message query
      conn.send_bind_message params
      conn.send_describe_portal_message
      conn.send_execute_message
      conn.send_sync_message
      conn.expect_frame Frame::ParseComplete
      conn.expect_frame Frame::BindComplete
      @fields = conn.expect_frame(Frame::RowDescription).fields
      @got_data = false
    end

    def get_data
      raise "already read data" if @got_data
      conn.read_all_data_rows { |row| yield row }
      conn.expect_frame Frame::ReadyForQuery
      @got_data = true
    end
  end
end
