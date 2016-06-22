class PG::Connection < ::DB::Connection
  protected getter connection

  def initialize(database)
    super
    conn_info = PQ::ConnInfo.new(database.uri)
    @connection = PQ::Connection.new(conn_info)
    @connection.connect
  end

  def build_statement(query)
    Statement.new(self, query)
  end

  def version
    query = "SELECT ver[1]::int AS major, ver[2]::int AS minor, ver[3]::int AS patch
               FROM regexp_matches(version(), 'PostgreSQL (\\d+)\\.(\\d+)\\.(\\d+)') ver"
    major, minor, patch = query_one query, &.read(Int32, Int32, Int32)
    {major: major, minor: minor, patch: patch}
  end

  protected def do_close
    @connection.close
  end
end
