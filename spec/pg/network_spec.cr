require "../spec_helper"
require "../../src/pg/network"

private def assert_roundtrip(x, sql_type, as cls)
  PG_DB.exec("create table test (a #{sql_type})")
  PG_DB.exec("insert into test values ($1)", x)
  value = PG_DB.query_one("select a from test", as: cls)
  value.should eq(x)
ensure
  PG_DB.exec("drop table test") rescue nil
end

describe "PG::Network" do
  describe "Inet" do
    it "decodes inet ipv4" do
      assert_roundtrip(PG::Network::Inet.new("192.168.1.1"), "inet", PG::Network::Inet)
    end

    it "decodes inet ipv4 with netmask" do
      assert_roundtrip(PG::Network::Inet.new("192.168.1.0", 24), "inet", PG::Network::Inet)
    end

    it "decodes inet ipv6" do
      assert_roundtrip(PG::Network::Inet.new("2001:db8::1"), "inet", PG::Network::Inet)
    end

    it "decodes inet ipv6 with netmask" do
      assert_roundtrip(PG::Network::Inet.new("2001:db8::", 64), "inet", PG::Network::Inet)
    end

    it "roundtrips with to_s" do
      inet = PG::Network::Inet.new("192.168.1.1", 24)
      inet.to_s.should eq("192.168.1.1/24")

      inet2 = PG::Network::Inet.new("192.168.1.1", 32)
      inet2.to_s.should eq("192.168.1.1")
    end
  end

  describe "Cidr" do
    it "decodes cidr ipv4" do
      assert_roundtrip(PG::Network::Cidr.new("192.168.0.0", 24), "cidr", PG::Network::Cidr)
    end

    it "decodes cidr ipv6" do
      assert_roundtrip(PG::Network::Cidr.new("2001:db8::", 32), "cidr", PG::Network::Cidr)
    end

    it "roundtrips with to_s" do
      cidr = PG::Network::Cidr.new("10.0.0.0", 8)
      cidr.to_s.should eq("10.0.0.0/8")
    end
  end

  describe "MacAddr" do
    it "decodes macaddr" do
      mac = PG::Network::MacAddr.new("08:00:2b:01:02:03")
      assert_roundtrip(mac, "macaddr", PG::Network::MacAddr)
    end

    it "accepts different formats" do
      mac1 = PG::Network::MacAddr.new("08:00:2b:01:02:03")
      mac2 = PG::Network::MacAddr.new("08-00-2b-01-02-03")

      mac1.to_s.should eq("08:00:2b:01:02:03")
      mac2.to_s.should eq("08:00:2b:01:02:03")
    end
  end

  describe "MacAddr8" do
    it "decodes macaddr8" do
      mac = PG::Network::MacAddr8.new("08:00:2b:01:02:03:04:05")
      assert_roundtrip(mac, "macaddr8", PG::Network::MacAddr8)
    end

    it "accepts different formats" do
      mac1 = PG::Network::MacAddr8.new("08:00:2b:01:02:03:04:05")
      mac2 = PG::Network::MacAddr8.new("08-00-2b-01-02-03-04-05")

      mac1.to_s.should eq("08:00:2b:01:02:03:04:05")
      mac2.to_s.should eq("08:00:2b:01:02:03:04:05")
    end
  end
end
