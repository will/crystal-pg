module PQ
  Log = ::Log.for("pg")

  class PgPass
    def self.locate(host : String, port : Int, db : String, user : String) : String?
      filename = ENV.fetch("PGPASSFILE", Path["~/.pgpass"].expand(home: true).to_s)

      unless (File.exists?(filename))
        Log.debug { "No pgpass file available" }

        return
      end

      unless (File.info(filename).permissions.to_i & 0o7177).zero?
        Log.warn { "Cannot use pgpass file - permissions are inappropriate must be 0600 or less" }
      end

      File.open(filename) do |f|
        while line = f.gets
          next if line.starts_with?("#")

          fields = line.split(":")

          unless fields.size == 5
            Log.warn { "PGPass file does not appear to be properly formatted - errors may occur" }
            next
          end

          next unless fields[0] == "*" || host == fields[0]
          next unless fields[1] == "*" || port == fields[1].to_i
          next unless fields[2] == "*" || db == fields[2]
          next unless fields[3] == "*" || user == fields[3]

          return fields[4]
        end
      end
    end
  end
end
