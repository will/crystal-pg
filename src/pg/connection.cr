require "../pq/*"

module PG
  class Connection < ::DB::Connection
    protected getter connection

    def initialize(database)
      super
      @connection = uninitialized PQ::Connection

      begin
        conn_info = PQ::ConnInfo.new(database.uri)
        @connection = PQ::Connection.new(conn_info)
        @connection.connect
      rescue
        raise DB::ConnectionRefused.new
      end
    end

    def build_prepared_statement(query)
      Statement.new(self, query)
    end

    def build_unprepared_statement(query)
      Statement.new(self, query)
    end

    # Execute several statements. No results are returned.
    def exec_all(query : String) : Nil
      PQ::SimpleQuery.new(@connection, query)
      nil
    end

    # Set the callback block for notices and errors.
    def on_notice(&on_notice_proc : PQ::Notice ->)
      @connection.notice_handler = on_notice_proc
    end

    # Set the callback block for notifications from Listen/Notify.
    def on_notification(&on_notification_proc : PQ::Notification ->)
      @connection.notification_handler = on_notification_proc
    end

    protected def listen(*channels : String)
      channels.each { |c| exec_all "LISTEN #{escape_identifier c}" }
      listen
    end

    protected def listen
      spawn { @connection.read_async_frame_loop }
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
end
