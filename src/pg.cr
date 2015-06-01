require "./core_ext/*"
require "./pg/*"

module PG
  def self.connect(conninfo)
    conn = Connection.new(conninfo)
    conn.exec("SET extra_float_digits = 3")
    conn
  end
end
