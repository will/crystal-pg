require "uri"

module PQ
  struct ConnInfo
    SOCKET_SEARCH = %w(/run/postgresql/.s.PGSQL.5432 /tmp/.s.PGSQL.5432 /var/run/postgresql/.s.PGSQL.5432)
    getter host : String
    getter port : Int32
    getter database : String
    getter user : String
    getter password : String?
    getter sslmode : Symbol

    def initialize(host : String? = nil, database : String? = nil, user : String? = nil, @password : String? = nil, port : Int | String? = 5432, sslmode : String | Symbol? = nil)
      @host = default_host host
      db = default_database database
      @database = db.starts_with?('/') ? db[1..-1] : db
      @user = default_user user
      @port = (port || 5432).to_i
      @sslmode = default_sslmode sslmode
    end

    # initialize with either "postgres://" urls or postgres "key=value" pairs
    def self.from_conninfo_string(conninfo : String)
      if conninfo.starts_with?("postgres://") || conninfo.starts_with?("postgresql://")
        new(URI.parse(conninfo))
      else
        return new if conninfo == ""

        args = Hash(String, String).new
        conninfo.split(' ').each do |pair|
          begin
            k, v = pair.split('=')
            args[k] = v
          rescue IndexError
            raise ArgumentError.new("invalid paramater: #{pair}")
          end
        end
        new(args)
      end
    end

    def initialize(uri : URI)
      sslmode = nil
      if q = uri.query
        q.split('&').each do |pair|
          k, v = pair.split('=')
          sslmode = v if k == "sslmode"
        end
      end

      initialize(uri.host, uri.path, uri.user, uri.password, uri.port, sslmode)
    end

    def initialize(params : Hash)
      initialize(params["host"]?, params["db_name"]?,
        params["user"]?, params["password"]?, params["port"]?, params["sslmode"]?)
    end

    private def default_host(h)
      return h if h

      SOCKET_SEARCH.each do |s|
        return s if File.exists?(s)
      end

      "localhost"
    end

    private def default_database(db)
      if db && db != "/"
        db
      else
        `whoami`.chomp
      end
    end

    private def default_user(u)
      u || `whoami`.chomp
    end

    private def default_sslmode(mode)
      case mode
      when nil, :prefer, "prefer"
        :prefer
      when :require, "require"
        :require
      else
        raise ArgumentError.new("sslmode #{mode} not supported")
      end
    end
  end
end
