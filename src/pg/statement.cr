class PG::Statement < ::DB::Statement
  def initialize(connection, @sql : String)
    super(connection)
  end

  protected def conn
    connection.as(Connection).connection
  end

  protected def perform_query(args : Enumerable) : ResultSet
    params = args.map { |arg| PQ::Param.encode(arg) }
    conn = self.conn
    conn.send_parse_message(@sql)
    conn.send_bind_message params
    conn.send_describe_portal_message
    conn.send_execute_message
    conn.send_sync_message
    conn.expect_frame PQ::Frame::ParseComplete
    conn.expect_frame PQ::Frame::BindComplete
    frame = conn.read
    case frame
    when PQ::Frame::RowDescription
      fields = frame.fields
    when PQ::Frame::NoData
      fields = nil
    else
      raise "expected RowDescription or NoData, got #{frame}"
    end
    ResultSet.new(self, fields)
  end

  protected def perform_exec(args : Enumerable) : ::DB::ExecResult
    result = perform_query(args)
    result.each { }
    # TODO: I don't know how to get these
    ::DB::ExecResult.new(rows_affected: 0_i64, last_insert_id: 0_i64)
  end
end
