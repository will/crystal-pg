module PG
  # Represents a PostgreSQL cursor for fetching query results in batches
  class Cursor
    getter connection : Connection
    getter query : String
    getter args : Array(PQ::Param)
    getter name : String

    @closed = false
    @result_set : ResultSet?

    def initialize(@connection : Connection, @query : String, args = [] of DB::Any, name : String? = nil)
      @name = name || "cursor_#{Time.utc.to_unix_ns}"
      @args = args.map { |arg| PQ::Param.encode(arg).as(PQ::Param) }

      # Start a transaction if not already in one
      unless connection.in_transaction?
        connection.exec("BEGIN")
      end

      # Declare the cursor
      declare_cursor
    end

    # Fetch a batch of rows from the cursor
    def fetch(count : Int32 = 100, &)
      check_closed

      result = connection.query("FETCH #{count} FROM #{escape_identifier(@name)}")
      if result.move_next
        yield result
      end
      result
    ensure
      result.try &.close
    end

    # Fetch all remaining rows
    def fetch_all(&)
      check_closed

      connection.query("FETCH ALL FROM #{escape_identifier(@name)}") do |rs|
        while rs.move_next
          yield rs
        end
      end
    end

    # Move the cursor position
    def move(offset : Int32)
      check_closed

      direction = offset >= 0 ? "FORWARD" : "BACKWARD"
      connection.exec("MOVE #{direction} #{offset.abs} FROM #{escape_identifier(@name)}")
    end

    # Move to absolute position
    def move_absolute(position : Int32)
      check_closed

      connection.exec("MOVE ABSOLUTE #{position} FROM #{escape_identifier(@name)}")
    end

    # Move to first row
    def move_first
      move_absolute(1)
    end

    # Move to last row
    def move_last
      check_closed

      connection.exec("MOVE LAST FROM #{escape_identifier(@name)}")
    end

    # Close the cursor
    def close
      return if @closed

      begin
        connection.exec("CLOSE #{escape_identifier(@name)}")
      ensure
        @closed = true
      end
    end

    # Check if cursor is closed
    def closed?
      @closed
    end

    private def declare_cursor
      if @args.empty?
        connection.exec("DECLARE #{escape_identifier(@name)} CURSOR FOR #{@query}")
      else
        # For parameterized queries, we need to bind the values directly in the query
        # because DECLARE CURSOR doesn't support parameter binding
        # This is a limitation of PostgreSQL cursors
        formatted_query = @query.dup
        @args.each_with_index do |arg, i|
          # Replace $1, $2, etc. with escaped literal values
          value = if arg.size == -1
                    "NULL"
                  else
                    connection.escape_literal(String.new(arg.slice))
                  end
          formatted_query = formatted_query.gsub("$#{i + 1}", value)
        end

        connection.exec("DECLARE #{escape_identifier(@name)} CURSOR FOR #{formatted_query}")
      end
    end

    private def check_closed
      raise DB::Error.new("Cursor is closed") if @closed
    end

    private def escape_identifier(name : String)
      connection.escape_identifier(name)
    end

    def finalize
      close unless @closed
    rescue
      # Ignore errors during finalization
    end
  end
end
