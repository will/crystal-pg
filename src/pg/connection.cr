require "../pq/*"

module PG
  class Connection < ::DB::Connection
    protected getter connection

    def initialize(options : ::DB::Connection::Options, conn_info : PQ::ConnInfo)
      begin
        connection = PQ::Connection.new(conn_info)
      rescue ex
        raise DB::ConnectionRefused.new(cause: ex)
      end
      initialize(options, connection)
    end

    def initialize(options : ::DB::Connection::Options, @connection : PQ::Connection)
      super(options)

      begin
        @connection.connect
      rescue ex
        raise DB::ConnectionRefused.new(cause: ex)
      end
    end

    def build_prepared_statement(query) : Statement
      Statement.new(self, query)
    end

    def build_unprepared_statement(query) : Statement
      Statement.new(self, query)
    end

    # Execute several statements. No results are returned.
    def exec_all(query : String) : Nil
      PQ::SimpleQuery.new(@connection, query)
      nil
    end

    # Execute a "COPY" query and return an IO object to read from or write to,
    # depending on the query.
    #
    # ```
    # data = conn.exec_copy("COPY table TO STDOUT").gets_to_end
    # ```
    #
    # ```
    # writer = conn.exec_copy "COPY table FROM STDIN")
    # writer << data
    # writer.close
    # ```
    def exec_copy(query : String) : CopyResult
      CopyResult.new connection, query
    end

    # Set the callback block for notices and errors.
    def on_notice(&on_notice_proc : PQ::Notice ->)
      @connection.notice_handler = on_notice_proc
    end

    # Set the callback block for notifications from Listen/Notify.
    def on_notification(&on_notification_proc : PQ::Notification ->)
      @connection.notification_handler = on_notification_proc
    end

    # `Time::Location.load` doesn't do any caching, so we cache it here to avoid
    # a time-zone lookup on every call to `time_zone`.
    @@location_cache = Hash(String, Time::Location).new do |cache, zone_name|
      cache[zone_name] = Time::Location.load(zone_name)
    end

    # Clears the cache for situations where the tzdata file has changed
    def clear_time_zone_cache
      @@location_cache.clear
    end

    def time_zone
      if zone_name = @connection.server_parameters["TimeZone"]?
        @@location_cache[zone_name]
      else
        Time::Location::UTC
      end
    end

    protected def listen(channels : Enumerable(String), blocking : Bool = false)
      channels.each { |c| exec_all("LISTEN " + escape_identifier(c)) }
      listen(blocking: blocking)
    end

    protected def listen(blocking : Bool = false)
      if blocking
        @connection.read_async_frame_loop
      else
        spawn { @connection.read_async_frame_loop }
      end
    end

    def version
      vers = connection.server_parameters["server_version"].partition(' ').first.split('.').map(&.to_i)
      {major: vers[0], minor: vers[1], patch: vers[2]? || 0}
    end

    protected def do_close
      super

      begin
        @connection.close
      rescue
      end
    end
  end
end
