class PG::Driver < ::DB::Driver
  def connection_builder(uri : URI) : Proc(::DB::Connection)
    params = HTTP::Params.parse(uri.query || "")
    options = connection_options(params)
    conn_info = PQ::ConnInfo.new(uri)
    ->{ Connection.new(options, conn_info).as(::DB::Connection) }
  end
end

DB.register_driver "postgres", PG::Driver
DB.register_driver "postgresql", PG::Driver
