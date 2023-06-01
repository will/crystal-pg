module PG
  module Extension
    abstract def load(connection : Connection)
  end
end
