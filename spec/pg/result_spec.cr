macro test_decode(name, select, expected)
  it {{name}} do
    rows = DB.exec("select #{{{select}}}").rows
    rows.size.should eq( 1 )
    rows.first.size.should eq( 1 )
    rows.first.first.should eq( {{expected}} )
  end
end

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

  it "can handle undefined types and several rows" do
    rows = DB.exec("select 'a', 'b' union all select '', null").rows
    rows.should eq([["a", "b"], ["", nil]])
  end

  test_decode "undefined as strings", "'what'", "what"
  test_decode "empty strings",        "''",     ""
  test_decode "null as nil",          "null",   nil
end
