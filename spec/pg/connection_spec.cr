require "../spec_helper"

describe PG::Connection, "#initialize" do
  it "works on a good connection" do
    PG::Connection.new(DB_URL)
  end

  it "raises on bad connections" do
    expect_raises(PG::ConnectionError) { PG::Connection.new("whatever") }
  end
end

describe PG::Connection, "#exec untyped" do
  it "returns a Result" do
    res = DB.exec("select 1")
    res.class.should eq(PG::Result(Array(PG::PGValue)))
  end

  it "raises on bad queries" do
    expect_raises(PG::ResultError) { DB.exec("select nocolumn from notable") }
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
    res.class.should eq(PG::Result({Int32.class}))
  end

  it "raises on bad queries" do
    expect_raises(PG::ResultError) { DB.exec({Int32}, "select nocolumn from notable") }
  end
end

describe PG::Connection, "#exec typed with params" do
  it "returns a Result" do
    res = DB.exec({Float64}, "select $1::float * $2::float ", [3.4, -2])
    res.class.should eq(PG::Result({Float64.class}))
  end

  it "raises on bad queries" do
    expect_raises(PG::ResultError) { DB.exec("select $1::text from notable", ["hello"]) }
  end
end

describe PG::Connection, "#exec untyped with params" do
  it "returns a Result" do
    res = DB.exec("select $1::text, $2::text, $3::text", ["hello", "", "world"])
    res.class.should eq(PG::Result(Array(PG::PGValue)))
  end

  it "raises on bad queries" do
    expect_raises(PG::ResultError) { DB.exec("select $1::text from notable", ["hello"]) }
  end

  it "can properly encode various types" do
    time = Time.new(2015, 5, 2, 13, 14, 15, 0, Time::Kind::Utc)
    date = Time.new(2015, 5, 2, 0, 0, 0, 0, Time::Kind::Utc)
    slice = Slice(UInt8).new(UInt8[5, 0, 255, 128].to_unsafe, 4)
    query = "select $1::text, $2::int, $3::text, $4::float, $5::timestamptz, $6::date, $7::bool, $8::bytea"
    param = ["hello", 2, nil, -4.23, time, date, true, slice]
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
