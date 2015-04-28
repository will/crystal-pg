describe PG::Result, "#fields" do
  it "is empty on empty results" do
    fields = DB.exec("select").fields
    fields.size.should eq(0)
  end

  it "is is a list of the fields" do
    fields = DB.exec("select 1 as one, 2 as two, 3 as three").fields
    fields.map(&.name).should eq(["one", "two", "three"])
    fields.map(&.oid).should eq([23,23,23])
  end
end

describe PG::Result, "#rows" do
  it "is an empty 2d array on empty results" do
    rows = DB.exec("select").rows
    rows.size.should    eq(1)
    rows[0].size.should eq(0)
  end

  it "can handle undefined types" do
    rows = DB.exec("select 'a', 'b' union all select 'c', 'd'").rows
    rows.should eq([["a", "b"], ["c", "d"]])
  end

  it "can handle empty strings and nulls" do
    rows = DB.exec("select 'a', '', null").rows
    rows.first.should eq( ["a", "", nil] )
  end
end
