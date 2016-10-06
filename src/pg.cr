require "db"
require "./pg/*"

module PG
  # Establish a connection to the database
  def self.connect(url)
    DB.open(url)
  end

  # Establish a special listen connection to the database
  def self.connect_listen(url, *channels : String, &blk : PQ::Notification ->) : ListenConnection
    ListenConnection.new(url, *channels, &blk)
  end

  class ListenConnection
    @db : DB::Database

    def initialize(url, *channels : String, &blk : PQ::Notification ->)
      @db = DB.open(url)
      @db.using_connection do |conn|
        conn = conn.as(PG::Connection)
        conn.on_notification(&blk)
        conn.listen(*channels)
      end
    end

    # Close the connection.
    def close
      @db.close
    end
  end
end
