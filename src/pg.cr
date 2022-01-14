require "db"
require "./pg/*"

module PG
  # Establish a connection to the database
  def self.connect(url)
    DB.open(url)
  end

  # Establish a special listen-only connection to the database.
  #
  # ```
  # PG.connect_listen(ENV["DATABASE_URL"], "foo", "bar") do |notification|
  #   pp notification.channel, notification.payload, notification.pid
  # end
  # ```
  #
  # By default, this will spawn a fiber to non-blocking listen. If you would
  # rather handle this yourself, pass true to the blocking parameter.
  #
  # ```
  # PG.connect_listen("postgres:///", "a", "b", blocking: true) { ... }
  # ```

  def self.connect_listen(url, *channels : String, blocking : Bool = false, &blk : PQ::Notification ->) : ListenConnection
    connect_listen(url, channels, blocking, &blk)
  end

  # ditto
  def self.connect_listen(url, channels : Enumerable(String), blocking : Bool = false, &blk : PQ::Notification ->) : ListenConnection
    ListenConnection.new(url, channels, blocking, &blk)
  end

  class ListenConnection
    @conn : PG::Connection

    def self.new(url, *channels : String, blocking : Bool = false, &blk : PQ::Notification ->)
      new(url, channels, blocking, &blk)
    end

    def initialize(url, channels : Enumerable(String), blocking : Bool = false, &blk : PQ::Notification ->)
      @conn = DB.connect(url).as(PG::Connection)
      @conn.on_notification(&blk)

      @conn.listen(channels, blocking: blocking)
    end

    # Close the connection.
    def close
      @conn.close
    rescue
    end
  end
end
