require "spec"
require "../src/pg"

DB_URL = ENV["DATABASE_URL"]? || "postgres:///"
DB     = PG.connect(DB_URL)

module Helper
  def self.db_version_gte(major, minor, patch = 0)
    ver = DB.version
    ver[:major] >= major && ver[:minor] >= minor && ver[:patch] >= patch
  end
end

def test_decode(name, query, expected, file = __FILE__, line = __LINE__)
  it name, file, line do
    rows = DB.exec("select #{query}").rows
    rows.size.should eq(1), file, line
    rows.first.size.should eq(1), file, line
    rows.first.first.should eq(expected), file, line
  end
end
