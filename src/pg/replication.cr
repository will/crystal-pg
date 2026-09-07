require "./replication/frame"
require "./replication/x_log_data"
require "./replication/copy_data"
require "./replication/standby_status_update"

module PG::Replication
  module Handler
    # This method must be defined in order to tell the `Connection` how much of
    # the WAL has been flushed and applied.
    #
    # ```
    # connection = PG.listen_replication db_url,
    #   handler: MyHandler.new,
    #   publication_name: "my_publication",
    #   slot_name: "my_replication_slot"
    #
    # class MyHandler
    #   include PG::Replication::Handler
    #
    #   def received(data : PG::Replication::XLogData, connection : PG::Replication::Connection, &)
    #     yield
    #     connection.last_wal_byte_flushed = data.wal_end
    #     if data.message.is_a? PG::Replication::Commit
    #       connection.last_wal_byte_applied = data.wal_end
    #     end
    #   end
    # end
    # ```
    abstract def received(data : PG::Replication::XLogData, connection : PG::Replication::Connection, &)

    # Override this method with any of the `WALMessage` subclasses to handle
    # receiving replication messages of that type.
    #
    # ```
    # class MyHandler
    #   include PG::Replication::Handler
    #
    #   # Using some hypothetical Kafka client for CDC
    #   def initialize(@kafka : Kafka::Client)
    #   end
    #
    #   def received(insert : PG::Replication::Insert)
    #     @kafka.publisher.publish({
    #       oid:  insert.oid,
    #       data: insert.tuple_data,
    #     }.to_msgpack)
    #   end
    # end
    # ```
    def received(frame)
    end
  end

  class Connection
    getter handler : Handler
    getter publication_name : String
    getter slot_name : String
    @uri : URI
    # How often the backstop fiber sends a standby status update to keep the
    # server from tripping its `wal_sender_timeout`. Ideally set to less than
    # half of that timeout to avoid being disconnected by the Postgres server.
    # Defaults to 10 seconds.
    getter keepalive_interval : Time::Span
    getter last_wal_byte_received = 0i64
    property last_wal_byte_flushed = 0i64
    property last_wal_byte_applied = 0i64
    getter? closed = false

    # :nodoc:
    def initialize(
      uri : URI | String,
      @handler,
      *,
      @publication_name,
      @slot_name,
      @keepalive_interval = 10.seconds,
      blocking : Bool = false,
    )
      if uri.is_a? String
        uri = URI.parse(uri)
      else
        uri = uri.dup
      end
      query_params = uri.query_params
      query_params["replication"] = "database"
      uri.query_params = query_params
      @uri = uri

      @conn = DB.connect(@uri).as(PG::Connection)

      # Periodically tell the server how far we've gotten so it can release WAL
      # segments we've already processed and keep the connection alive.
      spawn do
        until closed?
          sleep keepalive_interval
          begin
            send_keepalive
          rescue IO::Error
            # The connection dropped out from under us. `run_loop` handles
            # reconnection, so just skip this round.
          end
        end
      end

      if blocking
        run_loop
      else
        spawn { run_loop }
      end
    end

    # Consume the replication stream, reconnecting (and resuming from the last
    # flushed WAL position) whenever the connection drops, until `#close` is
    # called.
    private def run_loop
      backoff = base_reconnect_backoff
      until closed?
        begin
          @conn.listen_replication(
            publication_name: publication_name,
            slot_name: slot_name,
            start_lsn: last_wal_byte_flushed,
            blocking: true,
          ) do |frame|
            received frame
          end
          # `listen_replication` only returns when the socket is closed. If we
          # didn't close it ourselves, treat it as a drop and reconnect.
          break if closed?
        rescue ex : IO::Error
          break if closed?
          Log.warn(exception: ex) { "Replication connection lost; reconnecting" }
        rescue ex
          break if closed?
          Log.error(exception: ex) { "Unexpected error in replication loop; reconnecting" }
        end

        # The connection dropped. Re-establish it, backing off if the server
        # isn't ready yet.
        until closed?
          sleep backoff
          break if closed?
          begin
            reconnect
            backoff = base_reconnect_backoff
            break
          rescue ex
            backoff = {backoff * 2, max_reconnect_backoff}.min
            Log.error(exception: ex) { "Failed to reconnect replication; retrying in #{backoff}" }
          end
        end
      end
    end

    private def reconnect
      write_mutex.synchronize do
        begin
          @conn.close
        rescue
        end
        @conn = DB.connect(@uri).as(PG::Connection)
      end
    end

    private def base_reconnect_backoff
      1.second
    end

    private def max_reconnect_backoff
      30.seconds
    end

    # :nodoc:
    def received(frame : CopyBoth)
    end

    # :nodoc:
    def received(frame : CopyData)
      received frame.data
    end

    def received(frame : ErrorFrame)
    end

    # Handle the `XLogData` message that wraps `WALMessage`s
    def received(data : XLogData)
      @last_wal_byte_received = data.wal_end
      handler.received data, self do
        handler.received data.message
      end
    end

    # :nodoc:
    def received(keepalive : KeepAlive)
      send_keepalive if keepalive.response_expected?
    end

    # This shouldn't ever be received, but it can be represented in memory so we
    # need to include it for completeness.
    def received(response : KeepAliveResponse)
      raise NotImplementedError.new("KeepAliveResponses are intended to be sent, not received")
    end

    def close
      return if closed?
      # Flag the shutdown first so `run_loop` treats the imminent socket close
      # as deliberate rather than a dropped connection to reconnect.
      @closed = true
      # We attempt to send off one last keepalive to let the server know where
      # we left off.
      begin
        send_keepalive
      rescue IO::Error
      end
      @conn.close
    end

    def send_keepalive
      write { send_keepalive! }
    end

    private def send_keepalive! : Nil
      CopyData.new(
        StandbyStatusUpdate.new(
          last_wal_byte_received: last_wal_byte_received,
          last_wal_byte_flushed: last_wal_byte_flushed,
          last_wal_byte_applied: last_wal_byte_applied,
        )
      ).to_io socket

      flush
    end

    private def write(&)
      write_mutex.synchronize { yield }
    end

    private getter write_mutex = Mutex.new

    private def flush
      socket.flush
    end

    private def socket
      @conn.connection.soc
    end
  end

  # TODO: Implement the types below in order to support higher `proto_version`s

  # # StreamStart requires proto_version >= 2
  # struct StreamStart < WALMessage
  # end

  # # StreamStop requires proto_version >= 2
  # struct StreamStop < WALMessage
  # end

  # # StreamCommit requires proto_version >= 2
  # struct StreamCommit < WALMessage
  # end

  # # StreamAbort requires proto_version >= 2
  # struct StreamAbort < WALMessage
  # end

  # # BeginPrepare requires proto_version >=3
  # struct BeginPrepare < WALMessage
  # end

  # # Prepare requires proto_version >=3
  # struct Prepare < WALMessage
  # end

  # # CommitPrepared requires proto_version >=3
  # struct CommitPrepared < WALMessage
  # end

  # # RollbackPrepared requires proto_version >=3
  # struct RollbackPrepared < WALMessage
  # end

  # # StreamPrepare requires proto_version >=3
  # struct StreamPrepare < WALMessage
  # end
end
