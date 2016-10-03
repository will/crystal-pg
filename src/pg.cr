require "db"
require "./pg/*"

module PG
  # Establish a connection to the database
  def self.connect(url)
    DB.open(url)
  end

  # Establish a special listen connection to the database
  def self.connect_listen(url, *channels : String, &blk : PQ::Notification ->)
    db = DB.open(url)
    db.using_connection do |conn|
      conn.as(PG::Connection).listen(*channels, &blk)
    end
    db
  end
end
