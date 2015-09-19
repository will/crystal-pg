require "../spec_helper"

describe PG::Result, "#fields" do
  it "is empty on empty results" do
    if Helper.db_version_gte(9,4)
      fields = DB.exec("select").fields
      fields.size.should eq(0)
    end
  end

  it "is is a list of the fields" do
    fields = DB.exec("select 1 as one, 2 as two, 3 as three").fields
    fields.map(&.name).should eq(["one", "two", "three"])
    fields.map(&.oid).should eq([23,23,23])
  end
end

describe PG::Result, "#rows" do
  it "is an empty 2d array on empty results" do
    if Helper.db_version_gte(9,4)
      rows = DB.exec("select").rows
      rows.size.should    eq(1)
      rows[0].size.should eq(0)
    end
  end

  it "can handle several types and several rows" do
    rows = DB.exec(
             {String, PG::NilableString, Bool, Int32},
             "select 'a', 'b', true, 22 union all select '', null, false, 53"
           ).rows
    rows.should eq([{"a", "b", true,  22},
                    {"",  nil, false, 53}])
    [rows[0][0],    rows[1][0]].map(&.size).sum.should eq(1)
    (rows[0][2] && !rows[1][2]).should be_true
    (rows[0][3] <   rows[1][3]).should be_true
  end
end

describe PG::Result, "#to_hash" do
  it "represents the rows and fields as a hash" do
    res = DB.exec("select 'a' as foo, 'b' as bar, true as baz, 1.0::float as uhh
                   union all
                   select '', null, false, -3.2::float")
    res.to_hash.should eq([
      {"foo" => "a", "bar" => "b", "baz" => true,  "uhh" => 1.0},
      {"foo" => "",  "bar" => nil, "baz" => false, "uhh" => -3.2}
    ])
  end

  it "represents the rows and fields as a hash with typed querying" do
    res = DB.exec({String, String, Bool, Int32},
                  "select 'a' as foo, 'b' as bar, true as baz, 10 as uhh
                   union all
                   select '', 'c', false, 20")
    res.to_hash.should eq([
      {"foo" => "a", "bar" => "b", "baz" => true,  "uhh" => 10},
      {"foo" => "",  "bar" => "c", "baz" => false, "uhh" => 20}
    ])
  end

  it "raises if there are columns with the same name" do
    res = DB.exec("select 'a' as foo, 'b' as foo, 'c' as bar")
    expect_raises { res.to_hash }
  end
end
