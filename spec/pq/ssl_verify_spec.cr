require "../spec_helper"

# Gated like the auth specs: only runs when CRYSTAL_PG_CERT_DIR points at the
# test certs (set by the nix CI / the local tempdb helper). The server must be
# started with ssl=on and a server cert whose SAN is IP:127.0.0.1, signed by
# $CRYSTAL_PG_CERT_DIR/ca-cert.pem.
#
# All cases connect over 127.0.0.1 (always listening, and matching the cert
# SAN). The core security property — that an untrusted CA is rejected — is
# exercised for both verify-ca and verify-full. Two things are intentionally
# NOT asserted here because they cannot be tested reliably on loopback:
#   * verify-full rejecting a hostname mismatch (needs a non-SAN DNS name that
#     resolves to the listening address; loopback name resolution is
#     nondeterministic — `localhost` may resolve to ::1 — so it is flaky);
#   * verify-ca skipping the IP identity check (needs a reachable IP not in the
#     SAN; the only loopback candidate, ::1, currently hangs the driver on
#     connect — separate IPv6/connect-timeout issue).
if certs = ENV["CRYSTAL_PG_CERT_DIR"]?
  ssl_port = ENV["PGPORT"]? || "5432"
  ssl_ca = File.join(certs, "ca-cert.pem")
  ssl_db = PG_DB.query_one("select current_database()", &.read)

  describe PQ::Connection, "sslmode=verify-full" do
    it "connects with a trusted CA and a matching host" do
      DB.open("postgres://postgres@127.0.0.1:#{ssl_port}/#{ssl_db}?sslmode=verify-full&sslrootcert=#{ssl_ca}") do |db|
        db.scalar("select 1").should eq(1)
      end
    end

    it "fails when the server CA is untrusted (system store only)" do
      expect_raises(DB::ConnectionRefused) do
        DB.open("postgres://postgres@127.0.0.1:#{ssl_port}/#{ssl_db}?sslmode=verify-full")
      end
    end
  end

  describe PQ::Connection, "sslmode=verify-ca" do
    it "connects with a trusted CA" do
      DB.open("postgres://postgres@127.0.0.1:#{ssl_port}/#{ssl_db}?sslmode=verify-ca&sslrootcert=#{ssl_ca}") do |db|
        db.scalar("select 1").should eq(1)
      end
    end

    it "fails when the server CA is untrusted" do
      expect_raises(DB::ConnectionRefused) do
        DB.open("postgres://postgres@127.0.0.1:#{ssl_port}/#{ssl_db}?sslmode=verify-ca")
      end
    end
  end
end
