require "../spec_helper"

# The following specs requires specific lines in the local pg_hba.conf file
#   * crystal_md5 user with md5 method
#   * and if the line is trust for everything, it needs to be restricted to
#     just your user
# Because of this, most of these specs are disabled by default. To enable them
# place an empty file called .run_auth_specs in /spec

describe PQ::Connection, "nologin role" do
  it "raises" do
    DB.exec("drop role if exists crystal_test")
    DB.exec("create role crystal_test nologin")
    expect_raises(PQ::PQError) {
      PG::Connection.new("host=localhost user=crystal_test")
    }
    DB.exec("drop role if exists crystal_test")
  end
end

if File.exists?(File.join(File.dirname(__FILE__), "../.run_auth_specs"))
  describe PQ::Connection, "md5 auth" do
    it "works when given the correct password" do
      DB.exec("drop role if exists crystal_md5")
      DB.exec("create role crystal_md5 login encrypted password 'pass'")
      conn = PG::Connection.new("host=localhost user=crystal_md5 password=pass")
      conn.exec("select 1").rows.first.first.should eq(1)
      DB.exec("drop role if exists crystal_md5")
    end

    it "fails when given the wrong password" do
      DB.exec("drop role if exists crystal_md5")
      DB.exec("create role crystal_md5 login encrypted password 'pass'")

      expect_raises(PQ::PQError) {
        PG::Connection.new("host=localhost user=crystal_md5 password=bad")
      }

      expect_raises(PQ::PQError) {
        PG::Connection.new("host=localhost user=crystal_md5")
      }

      DB.exec("drop role if exists crystal_md5")
    end
  end
else
  describe "auth specs" do
    pending "skipped: see file for details" { }
  end
end
