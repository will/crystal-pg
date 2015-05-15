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
    res.class.should eq( PG::Result({Int32.class}) )
  end

  it "raises on bad queries" do
    expect_raises(PG::ResultError) { DB.exec({Int32}, "select nocolumn from notable") }
  end
end

describe PG::Connection, "#exec typed with params" do
  it "returns a Result" do
    res = DB.exec({Float64}, "select $1::float * $2::float ", [3.4, -2])
    res.class.should eq( PG::Result({Float64.class}) )
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
    time = Time.new(2015,05,02,13,14,15,0, Time::Kind::Utc)
    date = Time.new(2015,05,02, 0, 0, 0,0, Time::Kind::Utc)
    query = "select
             $1::text, $2::int, $3::text, $4::float, $5::timestamptz, $6::date, $7::bool"
    param =  ["hello",       2,    nil,    -4.23,      time,            date,       true]
    res = DB.exec(query, param)
    res.rows.should eq([param])
  end

end
