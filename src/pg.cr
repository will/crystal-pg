require "./pg/*"

module PG
  # Establish a connection to the database
  def self.connect(conninfo)
    Connection.new(conninfo)
  end

  # Establish a special listen connection to the database
  def self.connect_listen(conninfo, *channels : String, &blk : PQ::Notification ->)
    ListenConnection.new(conninfo, *channels, &blk)
  end
end
