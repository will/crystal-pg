class PG::Driver < ::DB::Driver
  class ConnectionBuilder < ::DB::ConnectionBuilder
    def initialize(@options : ::DB::Connection::Options, @conn_info : PQ::ConnInfo)
    end

    def build : ::DB::Connection
      PG::Connection.new(@options, @conn_info)
    end
  end

  def connection_builder(uri : URI) : ::DB::ConnectionBuilder
    params = HTTP::Params.parse(uri.query || "")
    ConnectionBuilder.new(connection_options(params), PQ::ConnInfo.new(uri))
  end
end

DB.register_driver "postgres", PG::Driver
DB.register_driver "postgresql", PG::Driver
