module PQ
  class ConnectionError < Exception
  end

  # Raised when the wire stream no longer matches the extended-query state
  # machine. Marks the physical connection as unusable; consumers must turn
  # this into a DB::ConnectionLost so the pool discards the connection.
  class ProtocolError < Exception
  end

  class PQError < Exception
    getter fields : Array(Frame::ErrorResponse::Field)

    def initialize(@fields)
      super(field_message :message)
    end

    def field_message(name)
      field = fields.find { |f| f.name == name }
      field.message if field
    end
  end
end
