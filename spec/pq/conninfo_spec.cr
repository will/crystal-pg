require "spec"
require "../../src/pq/conninfo"

private def assert_default_params(ci)
  ci.host.should eq("localhost")
  ci.database.should_not eq(nil)
  ci.user.should_not eq(nil)
  ci.database.should eq(ci.user)
  ci.password.should eq(nil)
  ci.port.should eq(5432)
end

private def assert_custom_params(ci)
  ci.host.should eq("host")
  ci.database.should eq("db")
  ci.user.should eq("user")
  ci.password.should eq("pass")
  ci.port.should eq(5555)
end

describe PQ::ConnInfo, "parts" do
  it "can have all defaults" do
    ci = PQ::ConnInfo.new
    assert_default_params ci
  end

  it "can take settings" do
    ci = PQ::ConnInfo.new("host", "db", "user", "pass", 5555)
    assert_custom_params ci
  end
end

describe PQ::ConnInfo, ".from_conninfo_string" do
  it "parses short postgres urls" do
    ci = PQ::ConnInfo.from_conninfo_string("postgres:///")
    assert_default_params ci
  end

  it "parses postgres urls" do
    ci = PQ::ConnInfo.from_conninfo_string(
      "postgres://user:pass@host:5555/db")
    assert_custom_params ci

    ci = PQ::ConnInfo.from_conninfo_string(
      "postgresql://user:pass@host:5555/db")
    assert_custom_params ci
  end

  it "parses libpq style strings" do
    ci = PQ::ConnInfo.from_conninfo_string(
      "host=host db_name=db user=user password=pass port=5555")
    assert_custom_params ci

    ci = PQ::ConnInfo.from_conninfo_string("host=host")
    ci.host.should eq("host")

    ci = PQ::ConnInfo.from_conninfo_string("host=host")
    ci.host.should eq("host")

    ci = PQ::ConnInfo.from_conninfo_string("")
    assert_default_params ci

    expect_raises(ArgumentError) {
      PQ::ConnInfo.from_conninfo_string("hosthost")
    }
  end
end
