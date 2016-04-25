require "../spec_helper"
require "uri"
describe PG::Connection, "#initialize" do
  it "works on a good connection" do
    PG::Connection.new(DB_URL)

    uri = URI.parse(DB_URL)
    info = {} of String => String
    info["host"] = uri.host as String if uri.host
    info["user"] = uri.user as String if uri.user
    info["password"] = uri.password as String if uri.password
    info["port"] = "#{uri.port}" if uri.port
    info["dbname"] = (uri.path as String).delete('/') if uri.path
    PG::Connection.new(info)
  end

  it "raises on bad connections" do
    # todo pending
    # expect_raises(PG::ConnectionError) { PG::Connection.new("whatever") }
  end
end

describe PG::Connection, "#exec untyped" do
  it "returns a Result" do
    res = DB.exec("select 1")
    res.rows # todo do something about not reading rows
    res.class.should eq(PG::Result(Array(PG::PGValue)))
  end

  it "raises on bad queries" do
    expect_raises(PQ::PQError) { DB.exec("select nocolumn from notable") }
  end

  it "returns a Result when create table" do
    res = DB.exec("create table if not exists test()")
    res.class.should eq(PG::Result(Array(PG::PGValue)))
    DB.exec("drop table test")
  end
end

describe PG::Connection, "#exec typed" do
  it "returns a Result" do
    res = DB.exec({Int32}, "select 1")
    res.rows # todo fix no reads
    res.class.should eq(PG::Result({Int32.class}))
  end

  it "raises on bad queries" do
    expect_raises(PQ::PQError) { DB.exec({Int32}, "select nocolumn from notable") }
  end
end

describe PG::Connection, "#exec typed with params" do
  it "returns a Result" do
    res = DB.exec({Float64}, "select $1::float * $2::float ", [3.4, -2])
    res.rows # todo fix when you don't take results
    res.class.should eq(PG::Result({Float64.class}))
  end

  it "raises on bad queries" do
    expect_raises(PQ::PQError) { DB.exec("select $1::text from notable", ["hello"]) }
  end
end

describe PG::Connection, "#exec untyped with params" do
  it "returns a Result" do
    res = DB.exec("select $1::text, $2::text, $3::text", ["hello", "", "world"])
    res.rows # todo fix when you don't take results
    res.class.should eq(PG::Result(Array(PG::PGValue)))
  end

  it "raises on bad queries" do
    expect_raises(PQ::PQError) { DB.exec("select $1::text from notable", ["hello"]) }
  end

  it "can properly encode various types" do
    time = Time.new(2015, 5, 2, 13, 14, 15, 0, Time::Kind::Utc)
    date = Time.new(2015, 5, 2, 0, 0, 0, 0, Time::Kind::Utc)
    slice = Slice(UInt8).new(UInt8[5, 0, 255, 128].to_unsafe, 4)
    query = "select $1::text, $2::text, $3::int, $4::text, $5::float, $6::timestamptz, $7::date, $8::bool, $9::bytea"
    param = ["hello", "", 2, nil, -4.23, time, date, true, slice]
    res = DB.exec(query, param)
    res.rows.should eq([param])
  end
end

describe PG::Connection, "#exec_all" do
  it "returns nil" do
    res = DB.exec_all("select 1; select 2;")
    res.class.should eq(Nil)
  end

  it "raises on bad queries" do
    expect_raises(PG::ResultError) { DB.exec_all("select 1; select nocolumn from notable;") }
  end
end

describe PG::Connection, "#escape_literal" do
  assert { DB.escape_literal(%(foo)).should eq(%('foo')) }
  assert { DB.escape_literal(%(some"thing)).should eq(%('some\"thing')) }
  assert { DB.escape_literal(%(foo).to_slice).should eq(%('\\x666f6f')) }
  it "raises on invalid strings" do
    expect_raises(PG::ConnectionError) { DB.escape_literal("\u{F4}") }
  end
end

describe PG::Connection, "#escape_identifier" do
  assert { DB.escape_identifier(%(foo)).should eq(%("foo")) }
  assert { DB.escape_identifier(%(someTHING)).should eq(%("someTHING")) }
  it "raises on invalid strings" do
    expect_raises(PG::ConnectionError) { DB.escape_identifier("\u{F4}") }
  end
end

describe PG::Connection, "#setup_notice_processor" do
  it "sends notices to on_notice" do
    last_notice = nil
    DB.on_notice do |notice|
      last_notice = notice
    end

    DB.exec_all <<-SQL
    SET client_min_messages TO notice;
    DO language plpgsql $$
    BEGIN
      RAISE NOTICE 'hello, world!';
    END
    $$;
    SQL
    last_notice.should eq("NOTICE:  hello, world!\n")
  end
end
