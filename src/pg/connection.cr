require "../pq/*"
require "./statement"
require "./result_set"

module PG
  class Connection < ::DB::Connection
    protected getter connection

    def initialize(context)
      super
      @connection = uninitialized PQ::Connection

      begin
        conn_info = PQ::ConnInfo.new(context.uri)
        @connection = PQ::Connection.new(conn_info)
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

    # Set the callback block for notices and errors.
    def on_notice(&on_notice_proc : PQ::Notice ->)
      @connection.notice_handler = on_notice_proc
    end

    # Set the callback block for notifications from Listen/Notify.
    def on_notification(&on_notification_proc : PQ::Notification ->)
      @connection.notification_handler = on_notification_proc
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
