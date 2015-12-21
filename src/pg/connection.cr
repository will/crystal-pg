require "./error"
require "../core_ext/scheduler"

module PG
  class Connection
    # :nodoc:
    record Param, slice, format do # Internal wrapper to represent an encoded parameter
      delegate to_unsafe, slice
      delegate size, slice

      # The only special case is nil->null and slice.
      # If more types need special cases, there should be an encoder
      def self.encode(val)
        if val.nil?
          binary Pointer(LibPQ::CChar).null.to_slice(0)
        elsif val.is_a? Slice
          binary val
        else
          text val.to_s.to_slice
        end
      end

      def self.binary(slice)
        new slice, 1
      end

      def self.text(slice)
        new slice, 0
      end
    end

    def initialize(conninfo : String)
      @conn_ptr = LibPQ.connect(conninfo)
      unless LibPQ.status(conn_ptr) == LibPQ::ConnStatusType::CONNECTION_OK
        error = ConnectionError.new(@conn_ptr)
        finish
        raise error
      end
    end

    def finalize
      finish
    end

    # `#initialize` Connect to the server with values of Hash.
    #
    #     PG::Connection.new({ "host": "localhost", "user": "postgres",
    #       "password":"password", "db_name": "test_db", "port": "5432" })
    def initialize(parameters : Hash)
      initialize(parameters.map { |param, value| "#{param}=#{value}" }.join(" "))
    end

    def exec(query : String)
      exec([] of PG::PGValue, query, [] of PG::PGValue)
    end

    def exec(query : String, params)
      exec([] of PG::PGValue, query, params)
    end

    def exec(types, query : String)
      exec(types, query, [] of PG::PGValue)
    end

    def exec(types, query : String, params)
      Result.new(types, libpq_exec(query, params))
    end

    def exec_all(query : String)
      res = LibPQ.exec(conn_ptr, query)
      check_status(res)
    end

    def finish
      if read_event = @read_event
        read_event.free
        @read_event = nil
      end
      LibPQ.finish(conn_ptr)
      @conn_ptr = nil
    end

    def version
      query = "SELECT ver[1]::int AS major, ver[2]::int AS minor, ver[3]::int AS patch
               FROM regexp_matches(version(), 'PostgreSQL (\\d+)\\.(\\d+)\\.(\\d+)') ver"
      version = exec({Int32, Int32, Int32}, query).rows.first
      {major: version[0], minor: version[1], patch: version[2]}
    end

    # `#escape_literal` escapes a string for use within an SQL command. This is
    # useful when inserting data values as literal constants in SQL commands.
    # Certain characters (such as quotes and backslashes) must be escaped to
    # prevent them from being interpreted specially by the SQL parser.
    # PQescapeLiteral performs this operation.
    #
    # Note that it is not necessary nor correct to do escaping when a data
    # value is passed as a separate parameter in `#exec`
    def escape_literal(str)
      escaped = LibPQ.escape_literal(conn_ptr, str, str.size)
      extract_escaped_result(escaped)
    end

    # `#escape_literal` escapes binary data suitable for use with the BYTEA type.
    def escape_literal(slice : Slice(UInt8))
      ssize = slice.size * 2 + 4
      String.new(ssize) do |buffer|
        buffer[0] = '\''.ord.to_u8
        buffer[1] = '\\'.ord.to_u8
        buffer[2] = 'x'.ord.to_u8
        slice.hexstring(buffer + 3)
        buffer[ssize - 1] = '\''.ord.to_u8
        {ssize, ssize}
      end
    end

    # `#escape_identifier` escapes a string for use as an SQL identifier, such
    # as a table, column, or function name. This is useful when a user-supplied
    # identifier might contain special characters that would otherwise not be
    # interpreted as part of the identifier by the SQL parser, or when the
    # identifier might contain upper case characters whose case should be
    # preserved.
    def escape_identifier(str)
      escaped = LibPQ.escape_identifier(conn_ptr, str, str.size)
      extract_escaped_result(escaped)
    end

    private getter conn_ptr

    private def libpq_exec(query, params)
      encoded_params = params.map { |v| Param.encode(v) }
      n_params = params.size
      param_types = Pointer(LibPQ::Int).null # have server infer types
      param_values = encoded_params.map &.to_unsafe
      param_lengths = encoded_params.map &.size
      param_formats = encoded_params.map &.format
      result_format = 1 # text vs. binary

      ret = LibPQ.send_query_params(
        conn_ptr,
        query,
        n_params,
        param_types,
        param_values,
        param_lengths,
        param_formats,
        result_format
      )
      if ret != 1
        raise Error.new(String.new(LibPQ.error_message(conn_ptr)))
      end

      libpq_get_result
    end

    private def libpq_get_result
      res = nil

      loop do
        wait_readable

        ret = LibPQ.get_result(conn_ptr)
        if ret == Pointer(Void).null
          break
        else
          check_status(res = ret, clear_results: true)
        end
      end

      res.not_nil!
    ensure
      libpq_clear_results
    end

    private def wait_readable
      if LibPQ.consume_input(conn_ptr) != 1
        raise Error.new(String.new(LibPQ.error_message(conn_ptr)))
      end
      if LibPQ.is_busy(conn_ptr) == 0
        return
      end

      # NOTE: no memoization: fiber is likely to change
      read_event = Scheduler.create_resume_event_on_read(Fiber.current, LibPQ.socket(conn_ptr))
      read_event.add
      Scheduler.reschedule
    ensure
      read_event.free if read_event
    end

    private def check_status(res, clear_results = false)
      status = LibPQ.result_status(res)
      return if (status == LibPQ::ExecStatusType::PGRES_TUPLES_OK ||
                status == LibPQ::ExecStatusType::PGRES_SINGLE_TUPLE ||
                status == LibPQ::ExecStatusType::PGRES_COMMAND_OK)
      libpq_clear_results if clear_results
      error = ResultError.new(res, status)
      LibPQ.clear(res)
      raise error
    end

    private def libpq_clear_results
      loop do
        res = LibPQ.get_result(conn_ptr)
        return if res == Pointer(Void).null
        LibPQ.clear(res)
        wait_readable
      end
    end

    private def extract_escaped_result(escaped)
      if escaped.null?
        error = ConnectionError.new(conn_ptr)
        raise error
      else
        result = String.new(escaped)
        LibPQ.freemem(escaped as Pointer(Void))
        result
      end
    end
  end
end
