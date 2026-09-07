require "../pq/*"
require "./statement"
require "./result_set"

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
        @connection.connect(replication: @connection.conninfo.replication)
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

    def pipeline
      pipeline = Pipeline.new(self)
      yield pipeline
      pipeline.results
    end

    # Execute several statements. No results are returned.
    def exec_all(query : String) : Nil
      PQ::SimpleQuery.new(@connection, query).exec
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

    protected def listen_replication(publication_name : String, slot_name : String, start_lsn : Int64 = 0i64, blocking : Bool = false, &block : Replication::Frame ->)
      if blocking
        @connection.start_replication_frame_loop(publication_name, slot_name, start_lsn, &block)
      else
        spawn { @connection.start_replication_frame_loop(publication_name, slot_name, start_lsn, &block) }
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

  struct Pipeline
    def initialize(@connection : Connection)
      @queries = [] of PQ::ExtendedQuery
    end

    def query(query, *args_, args : Array? = nil) : self
      ext_query = PQ::ExtendedQuery.new(@connection.connection, query, DB::EnumerableConcat.build(args_, args))
      @queries << ext_query.tap(&.send)
      self
    end

    def results
      @iterator ||= Results.new(@connection, @queries.each)
    end

    struct Results
      def initialize(@connection : Connection, @result_sets : Iterator(PQ::ExtendedQuery))
      end

      def scalar(type : T.class) forall T
        each type do |value|
          return value
        end
      end

      def read_one(type : T.class) forall T
        each(type) { |value| return value }
      end

      def read_one(types : Tuple)
        each(*types) { |value| return value }
      end

      def read_all(type : T.class) forall T
        results = Array(T).new

        each(type) do |row|
          results << row
        end
        results
      end

      def each(*type) forall T
        rs = self.next

        begin
          rs.each do
            yield rs.read(*type)
          end
        ensure
          rs.close
        end
      end

      def next
        case result = @result_sets.next
        when PQ::ExtendedQuery
          Statement::Pipelined.new(@connection, result.query).perform_query(result.params)
        else
          raise "Vespene geyser exhausted"
        end
      end
    end

    def close
      each
    end
  end
end
