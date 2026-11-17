require "../spec_helper"

# Specs using the certs from the nix test harness against a server with
# ssl=on.
#
# Test both 127.0.0.1 and localhost, because only one is in the cert,
# so it lets us distinguish verify-ca from verify-full.

SSL_PORT     = ENV["PGPORT"]? || "5432"
SSL_DATABASE = PG_DB.query_one("select current_database()", &.read)

private def ssl_url(host, sslmode, sslrootcert)
  "postgres://postgres@#{host}:#{SSL_PORT}/#{SSL_DATABASE}?sslmode=#{sslmode}&sslrootcert=#{sslrootcert}"
end

if certs = ENV["CRYSTAL_PG_CERT_DIR"]?
  ca = Path[certs, "ca-cert.pem"].to_s
  untrusted_ca = Path[certs, "other-ca-cert.pem"].to_s

  describe PQ::Connection, "sslmode=verify-full" do
    it "connects when the certificate is trusted and names the host" do
      DB.open(ssl_url("127.0.0.1", "verify-full", ca)) do |db|
        db.query_one("select 1", &.read).should eq(1)
        db.query_one("select ssl from pg_stat_ssl where pid = pg_backend_pid()", &.read).should be_true
      end
    end

    it "refuses a certificate that does not name the host" do
      exc = expect_raises(DB::ConnectionRefused) do
        DB.open(ssl_url("localhost", "verify-full", ca)) { }
      end
      exc.cause.try(&.message).to_s.should contain "certificate verify failed"
    end

    it "refuses a certificate signed by an untrusted CA" do
      exc = expect_raises(DB::ConnectionRefused) do
        DB.open(ssl_url("127.0.0.1", "verify-full", untrusted_ca)) { }
      end
      exc.cause.try(&.message).to_s.should contain "certificate verify failed"
    end
  end

  describe PQ::Connection, "sslmode=verify-ca" do
    it "connects when the certificate is trusted but does not name the host" do
      DB.open(ssl_url("localhost", "verify-ca", ca)) do |db|
        db.query_one("select 1", &.read).should eq(1)
        db.query_one("select ssl from pg_stat_ssl where pid = pg_backend_pid()", &.read).should be_true
      end
    end

    it "connects when the certificate is trusted and names the host" do
      DB.open(ssl_url("127.0.0.1", "verify-ca", ca)) do |db|
        db.query_one("select 1", &.read).should eq(1)
        db.query_one("select ssl from pg_stat_ssl where pid = pg_backend_pid()", &.read).should be_true
      end
    end

    it "refuses a certificate signed by an untrusted CA" do
      exc = expect_raises(DB::ConnectionRefused) do
        DB.open(ssl_url("127.0.0.1", "verify-ca", untrusted_ca)) { }
      end
      exc.cause.try(&.message).to_s.should contain "certificate verify failed"
    end
  end
end
