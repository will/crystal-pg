describe PG::Connection, "#initialize" do
  it "works on a good connection" do
    PG::Connection.new(DB_URL)
  end

  it "raises on bad connections" do
    expect_raises(PG::ConnectionError) { PG::Connection.new("whatever") }
  end
end

describe PG::Connection, "#exec" do
  it "returns a Result" do
    res = DB.exec("select 1")
    res.class.should eq(PG::Result)
  end

  it "raises on bad queries" do
    expect_raises(PG::ResultError) { DB.exec("select nocolumn from notable") }
  end
end
