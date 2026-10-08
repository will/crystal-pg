require "spec"
require "file_utils"
require "../../src/pg"

# Specs for TLS negotiation (`sslmode`, `sslrootcert`) against an in-process
# fake server. They need neither a Postgres server nor DATABASE_URL, so they
# do not load spec_helper.

# Test CAs and leaves made with the `openssl` CLI (OpenSSL 3: a negative
# `-days` yields an already-expired leaf).
module SslSpecCerts
  record Authority, cert_path : String, key_path : String
  record Leaf, cert_path : String, key_path : String

  def self.run!(args : Array(String))
    result = Process.run("openssl", args, error: Process::Redirect::Close, output: Process::Redirect::Close)
    raise "openssl #{args.first} failed" unless result.success?
  end

  def self.generate_ca(dir : String, name : String = "pg-spec-ca") : Authority
    id = Random::Secure.hex(6)
    cert, key = File.join(dir, "ca-#{id}.pem"), File.join(dir, "ca-key-#{id}.pem")
    run!(["req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", key, "-out", cert,
          "-days", "1", "-subj", "/CN=#{name}",
          "-addext", "basicConstraints=critical,CA:TRUE",
          "-addext", "keyUsage=critical,keyCertSign,cRLSign"])
    Authority.new(cert, key)
  end

  def self.issue(dir : String, ca : Authority, san : String = "IP:127.0.0.1", days : Int32 = 1) : Leaf
    id = Random::Secure.hex(6)
    cert, key = File.join(dir, "cert-#{id}.pem"), File.join(dir, "key-#{id}.pem")
    csr, ext = File.join(dir, "csr-#{id}.pem"), File.join(dir, "ext-#{id}.cnf")
    File.write(ext, "subjectAltName = #{san}\nbasicConstraints = CA:FALSE\nkeyUsage = critical,digitalSignature,keyEncipherment\nextendedKeyUsage = serverAuth\n")
    run!(["req", "-new", "-newkey", "rsa:2048", "-nodes", "-keyout", key, "-out", csr, "-subj", "/CN=pg-spec"])
    run!(["x509", "-req", "-in", csr, "-CA", ca.cert_path, "-CAkey", ca.key_path,
          "-set_serial", "0x#{Random::Secure.hex(8)}", "-days", days.to_s, "-extfile", ext, "-out", cert])
    Leaf.new(cert, key)
  end

  def self.generate_trusted(dir : String) : {Authority, Leaf}
    ca = generate_ca(dir)
    {ca, issue(dir, ca)}
  end
end

# An in-process stand-in for a Postgres server's SSL negotiation, so these
# specs need no Postgres server. It
# listens on 127.0.0.1 on an ephemeral port, reads the 8-byte SSL request,
# answers `S` or `N`, optionally completes a TLS handshake with a given leaf,
# and reports what the client sent afterwards.
class FakePgTlsServer
  SSL_REQUEST_CODE = 80877103_u32
  PROTOCOL_3_0     =   196608_u32

  # What the server saw for one connection. *startup* is where a startup message
  # (length plus protocol 196608) arrived, if one did; *plaintext_bytes* counts
  # the bytes received in plaintext after the answer was sent.
  record Observation,
    ssl_request : Bool,
    answer : Char,
    handshake_completed : Bool,
    startup : Symbol?,
    plaintext_bytes : Int32

  getter port : Int32
  @server : TCPServer
  @result = Channel(Observation).new(1)

  # *cert_path* and *key_path* are the leaf the server presents on `S`. Without
  # them an `S` answer is followed by closing the socket.
  def initialize(@answer : Char, @cert_path : String? = nil, @key_path : String? = nil)
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.local_address.port
    spawn handle_one
  end

  def host : String
    "127.0.0.1"
  end

  def url(sslmode : String, sslrootcert : String? = nil) : String
    query = "sslmode=#{sslmode}"
    query += "&sslrootcert=#{URI.encode_www_form(sslrootcert)}" if sslrootcert
    "postgres://corduroy:secret@#{host}:#{port}/corduroy?#{query}"
  end

  # Waits (bounded) for the observation, then stops listening.
  def observation : Observation
    select
    when obs = @result.receive
      obs
    when timeout(5.seconds)
      raise "fake pg server saw no connection"
    end
  ensure
    @server.close unless @server.closed?
  end

  private def handle_one
    sock = @server.accept
    sock.read_timeout = 2.seconds
    sock.sync = false
    request = Bytes.new(8)
    read = (sock.read_fully(request) rescue nil)
    unless read
      @result.send(Observation.new(false, '-', false, nil, 0))
      return
    end
    format = IO::ByteFormat::NetworkEndian
    ssl_request = format.decode(UInt32, request[0, 4]) == 8_u32 && format.decode(UInt32, request[4, 4]) == SSL_REQUEST_CODE
    sock.write_byte(@answer.ord.to_u8)
    sock.flush

    if @answer == 'S' && (cert = @cert_path) && (key = @key_path)
      ctx = OpenSSL::SSL::Context::Server.new
      ctx.certificate_chain = cert
      ctx.private_key = key
      begin
        tls = OpenSSL::SSL::Socket::Server.new(sock, ctx, sync_close: true)
      rescue
        @result.send(Observation.new(ssl_request, @answer, false, nil, 0))
        return
      end
      startup = startup_message?(tls) ? :tls : nil
      @result.send(Observation.new(ssl_request, @answer, true, startup, 0))
      tls.close rescue nil
    else
      buffer = Bytes.new(1024)
      count = (sock.read(buffer) rescue 0)
      startup = count >= 8 && format.decode(UInt32, buffer[4, 4]) == PROTOCOL_3_0 ? :plain : nil
      @result.send(Observation.new(ssl_request, @answer, false, startup, count))
      sock.close rescue nil
    end
  rescue
    @result.send(Observation.new(false, '-', false, nil, 0)) rescue nil
  end

  private def startup_message?(io : IO) : Bool
    header = Bytes.new(8)
    io.read_fully(header)
    IO::ByteFormat::NetworkEndian.decode(UInt32, header[4, 4]) == PROTOCOL_3_0
  rescue
    false
  end
end

private STARTUP = ["user", "corduroy", "database", "corduroy"]

# Connects the way crystal-pg's connection does (negotiate, then startup) and
# returns the error raised, if any.
private def attempt(url : String) : Exception?
  conn = PQ::Connection.new(PQ::ConnInfo.new(URI.parse(url)))
  begin
    conn.startup(STARTUP)
    # The fake server closes once it has read the startup message; waiting for
    # that EOF keeps the client from tearing the socket down mid-handshake.
    conn.soc.read(Bytes.new(1)) rescue nil
  ensure
    conn.soc.close rescue nil
  end
  nil
rescue ex
  ex
end

private def with_certs(&)
  dir = File.join(Dir.tempdir, "pgtls-#{Random::Secure.hex(6)}")
  Dir.mkdir_p(dir)
  begin
    yield dir
  ensure
    FileUtils.rm_rf(dir)
  end
end

describe "PQ::Connection#negotiate_ssl" do
  describe "verify-full" do
    it "accepts a trusted certificate for the host and starts up over TLS" do
      with_certs do |dir|
        ca, leaf = SslSpecCerts.generate_trusted(dir)
        server = FakePgTlsServer.new('S', leaf.cert_path, leaf.key_path)
        attempt(server.url("verify-full", ca.cert_path)).should be_nil
        obs = server.observation
        obs.handshake_completed.should be_true
        obs.startup.should eq :tls
      end
    end

    it "rejects a self-signed certificate" do
      with_certs do |dir|
        trusted = SslSpecCerts.generate_ca(dir)
        rogue = SslSpecCerts.generate_ca(dir, "rogue")
        server = FakePgTlsServer.new('S', rogue.cert_path, rogue.key_path)
        attempt(server.url("verify-full", trusted.cert_path)).should be_a(PQ::ConnectionError)
        server.observation.startup.should be_nil
      end
    end

    it "rejects a self-signed certificate under sslrootcert=system" do
      with_certs do |dir|
        rogue = SslSpecCerts.generate_ca(dir, "rogue")
        server = FakePgTlsServer.new('S', rogue.cert_path, rogue.key_path)
        attempt(server.url("verify-full", "system")).should be_a(PQ::ConnectionError)
        server.observation.startup.should be_nil
      end
    end

    it "rejects a trusted certificate issued for another host" do
      with_certs do |dir|
        ca = SslSpecCerts.generate_ca(dir)
        leaf = SslSpecCerts.issue(dir, ca, "DNS:wrong.example")
        server = FakePgTlsServer.new('S', leaf.cert_path, leaf.key_path)
        attempt(server.url("verify-full", ca.cert_path)).should be_a(PQ::ConnectionError)
        server.observation.startup.should be_nil
      end
    end

    it "rejects an expired certificate" do
      with_certs do |dir|
        ca = SslSpecCerts.generate_ca(dir)
        leaf = SslSpecCerts.issue(dir, ca, days: -1)
        server = FakePgTlsServer.new('S', leaf.cert_path, leaf.key_path)
        attempt(server.url("verify-full", ca.cert_path)).should be_a(PQ::ConnectionError)
        server.observation.startup.should be_nil
      end
    end

    it "fails, sending nothing in plaintext, when the server answers N" do
      server = FakePgTlsServer.new('N')
      attempt(server.url("verify-full")).should be_a(PQ::ConnectionError)
      obs = server.observation
      obs.startup.should be_nil
      obs.plaintext_bytes.should eq 0
    end
  end

  describe "verify-ca" do
    it "accepts a trusted certificate issued for another host" do
      with_certs do |dir|
        ca = SslSpecCerts.generate_ca(dir)
        leaf = SslSpecCerts.issue(dir, ca, "DNS:wrong.example")
        server = FakePgTlsServer.new('S', leaf.cert_path, leaf.key_path)
        attempt(server.url("verify-ca", ca.cert_path)).should be_nil
        server.observation.startup.should eq :tls
      end
    end

    it "rejects a self-signed certificate" do
      with_certs do |dir|
        trusted = SslSpecCerts.generate_ca(dir)
        rogue = SslSpecCerts.generate_ca(dir, "rogue")
        server = FakePgTlsServer.new('S', rogue.cert_path, rogue.key_path)
        attempt(server.url("verify-ca", trusted.cert_path)).should be_a(PQ::ConnectionError)
        server.observation.startup.should be_nil
      end
    end

    it "fails, sending nothing in plaintext, when the server answers N" do
      server = FakePgTlsServer.new('N')
      attempt(server.url("verify-ca")).should be_a(PQ::ConnectionError)
      obs = server.observation
      obs.startup.should be_nil
      obs.plaintext_bytes.should eq 0
    end
  end

  describe "require" do
    it "accepts a self-signed certificate without sslrootcert (unchanged)" do
      with_certs do |dir|
        rogue = SslSpecCerts.generate_ca(dir, "rogue")
        server = FakePgTlsServer.new('S', rogue.cert_path, rogue.key_path)
        attempt(server.url("require")).should be_nil
        server.observation.startup.should eq :tls
      end
    end

    it "verifies the chain when sslrootcert names a file (libpq behavior)" do
      with_certs do |dir|
        trusted = SslSpecCerts.generate_ca(dir)
        rogue = SslSpecCerts.generate_ca(dir, "rogue")
        server = FakePgTlsServer.new('S', rogue.cert_path, rogue.key_path)
        attempt(server.url("require", trusted.cert_path)).should be_a(PQ::ConnectionError)
        server.observation.startup.should be_nil
      end
    end

    it "fails when the server answers N (unchanged)" do
      server = FakePgTlsServer.new('N')
      attempt(server.url("require")).should be_a(PQ::ConnectionError)
      server.observation.startup.should be_nil
    end
  end

  describe "prefer" do
    it "falls back to plaintext when the server answers N (unchanged)" do
      server = FakePgTlsServer.new('N')
      attempt(server.url("prefer")).should be_nil
      server.observation.startup.should eq :plain
    end
  end
end
