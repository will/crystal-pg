module PG
  class Error < ::Exception
  end

  class ConnectionError < Error
    def initialize(raw_connection)
      msg = String.new(LibPQ.error_message(raw_connection))
      super(msg)
    end
  end

  class ResultError < Error
    def initialize(raw_result, @status : LibPQ::ExecStatusType)
      msg = String.new(LibPQ.result_error_message(raw_result))
      super(msg)
    end
  end

  class RuntimeError < Error
  end
end
