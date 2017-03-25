require "../pq/*"

module PG
  class Connection < ::DB::Connection
    protected getter connection

    @decoders : Decoders::DecoderMap?

    def initialize(context)
      super
      @connection = uninitialized PQ::Connection

      begin
        conn_info = PQ::ConnInfo.new(context.uri)
        @connection = PQ::Connection.new(conn_info)
        @connection.connect

        # We have to query `pg_type` table to learn about the types in this
        # database, so make sure we temporarily set `auto_release` to false
        # else this would cause a premature `release` before this connection
        # has even been added to the pool.
        self.auto_release, auto_release = false, self.auto_release
        @decoders = Decoders.build_decoder_list(self)
        self.auto_release = auto_release
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

    def decoder_from_oid(oid)
      decoders = @decoders
      if decoders.nil?
        # We haven't built the connection-specific decoders up yet (this is
        # probably happening in the caller), so fallback to the default known list.
        Decoders.from_oid(oid)
      else
        decoders.fetch(oid) { Decoders.from_oid(oid) }
      end
    end

    protected def do_close
      @connection.close
    end
  end
end
