require "../spec_helper"

# The following specs requires specific lines in the local pg_hba.conf file
#   * crystal_md5 user with md5 method
#   * and if the line is trust for everything, it needs to be restricted to
#     just your user
# Because of this, most of these specs are disabled by default. To enable them
# place an empty file called .run_auth_specs in /spec

private def other_role(pass)
  db = PG_DB.query_one("select current_database()", &.read)
  "postgres://crystal_md5:#{pass}@127.0.0.1/#{db}"
end

describe PQ::Connection, "nologin role" do
  it "raises" do
    PG_DB.exec("drop role if exists crystal_test")
    PG_DB.exec("create role crystal_test nologin")
    expect_raises(DB::ConnectionRefused) {
      DB.open("postgres://crystal_test@localhost")
    }
    PG_DB.exec("drop role if exists crystal_test")
  end
end

if File.exists?(File.join(File.dirname(__FILE__), "../.run_auth_specs"))
  describe PQ::Connection, "md5 auth" do
    it "works when given the correct password" do
      PG_DB.exec("drop role if exists crystal_md5")
      PG_DB.exec("create role crystal_md5 login encrypted password 'pass'")
      DB.open(other_role("pass")) do |db|
        db.query_one("select 1", &.read).should eq(1)
      end
      PG_DB.exec("drop role if exists crystal_md5")
    end

    it "fails when given the wrong password" do
      PG_DB.exec("drop role if exists crystal_md5")
      PG_DB.exec("create role crystal_md5 login encrypted password 'pass'")

      expect_raises(DB::ConnectionRefused) {
        DB.open(other_role("bad"))
      }

      expect_raises(DB::ConnectionRefused) {
        DB.open(other_role(""))
      }

      PG_DB.exec("drop role if exists crystal_md5")
    end
  end

  describe PQ::Connection, "ssl clientcert auth" do
    it "works when using ssl clientcert" do
      PG_DB.exec("drop role if exists crystal_ssl")
      PG_DB.exec("create role crystal_ssl login encrypted password 'pass'")
      db = PG_DB.query_one("select current_database()", &.read)
      home = ENV["HOME"]
      uri = "postgres://crystal_ssl@127.0.0.1/#{db}?sslmode=verify-full&sslcert=#{home}/.postgresql/crystal_ssl.crt&sslkey=#{home}/.postgresql/crystal_ssl.key&sslrootcert=#{home}/.postgresql/root.crt"
      DB.open(uri) do |db|
        db.query_one("select current_user", &.read).should eq("crystal_ssl")
      end
      PG_DB.exec("drop role if exists crystal_ssl")
    end
  end
else
  describe "auth specs" do
    pending "skipped: see file for details" { }
  end
end
