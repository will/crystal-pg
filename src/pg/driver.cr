class PG::Driver < ::DB::Driver
  def build_connection(db)
    Connection.new(db)
  end
end

DB.register_driver "postgres", PG::Driver
