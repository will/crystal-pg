require "spec"
require "../src/pg"

DB_URL = ENV["DATABASE_URL"]? || "postgres:///"
$DB = PG.connect(DB_URL)

module Helper
  def self.db_version_gte(major, minor, patch=0)
    ver = $DB.version
    ver[:major] >= major && ver[:minor] >= minor && ver[:patch] >= patch
  end
end
