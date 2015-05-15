require "./core_ext/*"
require "./pg/*"

module PG
  def self.connect(conninfo)
    Connection.new(conninfo)
  end
end
