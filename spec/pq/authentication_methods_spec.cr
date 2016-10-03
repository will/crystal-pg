require "../spec_helper"

# The following specs requires specific lines in the local pg_hba.conf file
#   * crystal_md5 user with md5 method
#   * and if the line is trust for everything, it needs to be restricted to
#     just your user
# Because of this, most of these specs are disabled by default. To enable them
# place an empty file called .run_auth_specs in /spec

describe PQ::Connection, "nologin role" do
  it "raises" do
    PG_DB.exec("drop role if exists crystal_test")
    PG_DB.exec("create role crystal_test nologin")
    expect_raises(PQ::PQError) {
      DB.open("postgres://crystal_test@localhost")
    }
    PG_DB.exec("drop role if exists crystal_test")
  end
end

if File.exists?(File.join(File.dirname(__FILE__), "../.run_auth_specs"))
  describe PQ::Connection, "cleartext auth" do
    it "works when given the correct password" do
      PG_DB.exec("drop role if exists crystal_pass")
      PG_DB.exec("create role crystal_pass login encrypted password 'pass'")
      DB.open("postgres://crystal_pass:pass@localhost") do |db|
        db.query_one("select 1", &.read).should eq(1)
      end
      PG_DB.exec("drop role if exists crystal_pass")
    end

    it "fails when given the wrong password" do
      PG_DB.exec("drop role if exists crystal_pass")
      PG_DB.exec("create role crystal_pass login encrypted password 'pass'")

      expect_raises(PQ::PQError) {
        DB.open("postgres://crystal_pass:bad@localhost")
      }

      expect_raises(PQ::PQError) {
        DB.open("postgres://crystal_pass@localhost")
      }

      PG_DB.exec("drop role if exists crystal_pass")
    end
  end

  describe PQ::Connection, "md5 auth" do
    it "works when given the correct password" do
      PG_DB.exec("drop role if exists crystal_md5")
      PG_DB.exec("create role crystal_md5 login encrypted password 'pass'")
      DB.open("postgres://crystal_md5:pass@localhost") do |db|
        db.query_one("select 1", &.read).should eq(1)
      end
      PG_DB.exec("drop role if exists crystal_md5")
    end

    it "fails when given the wrong password" do
      PG_DB.exec("drop role if exists crystal_md5")
      PG_DB.exec("create role crystal_md5 login encrypted password 'pass'")

      expect_raises(PQ::PQError) {
        DB.open("postgres://crystal_md5:bad@localhost")
      }

      expect_raises(PQ::PQError) {
        DB.open("postgres://crystal_md5@localhost")
      }

      PG_DB.exec("drop role if exists crystal_md5")
    end
  end
else
  describe "auth specs" do
    pending "skipped: see file for details" { }
  end
end
