module PQ
  struct ConnInfo
    getter host : String
    getter port : Int32
    getter database : String
    getter user : String
    getter password : String?

    def initialize(host = nil, database = nil, user = nil, @password = nil, port = 5432)
      @host = default_host host
      db = default_database database
      @database = db.starts_with?('/') ? db[1..-1] : db
      @user = default_user user
      @port = (port || 5432).to_i
    end

    # initialize with either "postgres://" urls or postgres "key=value" pairs
    def initialize(conninfo : String)
      if conninfo.starts_with?("postgres://") || conninfo.starts_with?("postgresql://")
        initialize(URI.parse(conninfo))
      else
        args = Hash(String, String).new
        conninfo.split(' ').each do |pair|
          k, v = pair.split('=')
          args[k] = v
        end
        initialize(args)
      end
    end

    def initialize(uri : URI)
      initialize(uri.host, uri.path, uri.user, uri.password, uri.port)
    end

    def initialize(params : Hash)
      initialize(params["host"]?, params["db_name"]?,
        params["user"]?, params["password"]?, params["port"]?)
    end

    private def default_host(h)
      h || "localhost"
    end

    private def default_database(db)
      db || `whoami`.chomp
    end

    private def default_user(u)
      u || `whoami`.chomp
    end
  end
end
