require "../spec_helper"

# The following specs requires specific lines in the local pg_hba.conf file
#   * crystal_md5 user with md5 method
#   * and if the line is trust for everything, it needs to be restricted to
#     just your user
# Because of this, most of these specs are disabled by default. To enable them
# place an empty file called .run_auth_specs in /spec

private def test_role(role, pass)
  db = PG_DB.query_one("select current_database()", &.read)
  url = "postgres://#{role}:#{pass}@127.0.0.1/#{db}"
  DB.open(url) do |db|
    db.query_one("select 1", &.read).should eq(1)
  end
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
  describe PQ::Connection, "scram auth" do
    it "works when given the correct password" do
      PG_DB.exec("drop role if exists crystal_scram")
      PG_DB.exec("set password_encryption='scram-sha-256'")
      PG_DB.exec("create role crystal_scram login encrypted password 'pass'")

      test_role("crystal_scram", "pass")

      [                        # saslprep examples from MagicStack/asyncpg
        "nonascii\u1680space", # C.1.2
        "common\u1806nothing", # B.1
        "ab\ufb01c",           # normalization
        "ab\u007fc",           # C.2.1
        "ab\u206ac",           # C.2.2, C.6
        "ab\ue000c",           # C.3, C.5
        "ab\ufdd0c",           # C.4
        "ab\u2ff0c",           # C.7
        "ab\u2000c",           # C.8
        "ab\ue0001",           # C.9
      ].each do |pass|
        PG_DB.exec("alter role crystal_scram with password '#{pass}'")
        test_role("crystal_scram", pass)
      rescue DB::ConnectionRefused
        raise "password #{pass.inspect} faild sasl prep"
      end

      PG_DB.exec("drop role if exists crystal_scram")
    end

    it "fails with a bad password" do
      PG_DB.exec("drop role if exists crystal_scram")
      PG_DB.exec("set password_encryption='scram-sha-256'")
      PG_DB.exec("create role crystal_scram login encrypted password 'pass'")

      expect_raises(DB::ConnectionRefused) {
        test_role("crystal_scram", "wrong")
      }

      expect_raises(DB::ConnectionRefused) {
        test_role("crystal_scram", "")
      }

      PG_DB.exec("drop role if exists crystal_scram")
    end
  end if Helper.db_version_gte(10)

  describe PQ::Connection, "md5 auth" do
    it "works when given the correct password" do
      PG_DB.exec("drop role if exists crystal_md5")
      PG_DB.exec("set password_encryption='md5'") if Helper.db_version_gte(10)
      PG_DB.exec("create role crystal_md5 login encrypted password 'pass'")
      test_role("crystal_md5", "pass")
      PG_DB.exec("drop role if exists crystal_md5")
    end

    it "fails when given the wrong password" do
      PG_DB.exec("drop role if exists crystal_md5")
      PG_DB.exec("set password_encryption='md5'") if Helper.db_version_gte(10)
      PG_DB.exec("create role crystal_md5 login encrypted password 'pass'")

      expect_raises(DB::ConnectionRefused) {
        test_role("crystal_md5", "bad")
      }

      expect_raises(DB::ConnectionRefused) {
        test_role("crystal_md5", "")
      }

      PG_DB.exec("drop role if exists crystal_md5")
    end
  end

  describe PQ::Connection, "ssl clientcert auth" do
    it "works when using ssl clientcert" do
      PG_DB.exec("drop role if exists crystal_ssl")
      PG_DB.exec("create role crystal_ssl login encrypted password 'pass'")
      db = PG_DB.query_one("select current_database()", &.read)
      certs = File.join Dir.current, ".cert"
      uri = "postgres://crystal_ssl@127.0.0.1/#{db}?sslmode=verify-full&sslcert=#{certs}/crystal_ssl.crt&sslkey=#{certs}/crystal_ssl.key&sslrootcert=#{certs}/root.crt"
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
