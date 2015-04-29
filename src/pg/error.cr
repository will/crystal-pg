module PG
  class Error < ::Exception

  end

  class ConnectionError < Error
    def initialize(raw_connection)
      msg = String.new(LibPQ.error_message(raw_connection))
      super(msg)
    end
  end
end
