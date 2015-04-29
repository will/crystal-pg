describe PG::Connection, "#initialize" do
  it "works on a good connection" do
    PG::Connection.new(DB_URL)
  end

  it "raises on bad connections" do
    expect_raises(PG::ConnectionError) { PG::Connection.new("whatever") }
  end
end
