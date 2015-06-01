require "../spec_helper"

macro test_decode(name, select, expected, file = __FILE__, line = __LINE__)
  it {{name}}, {{file}}, {{line}} do
    rows = $DB.exec("select #{{{select}}}").rows
    rows.size.should eq( 1 )
    rows.first.size.should eq( 1 )
    rows.first.first.should eq( {{expected}} )
  end
end

describe PG::Result, "#fields" do
  it "is empty on empty results" do
    if Helper.db_version_gte(9,4)
      fields = $DB.exec("select").fields
      fields.size.should eq(0)
    end
  end

  it "is is a list of the fields" do
    fields = $DB.exec("select 1 as one, 2 as two, 3 as three").fields
    fields.map(&.name).should eq(["one", "two", "three"])
    fields.map(&.oid).should eq([23,23,23])
  end
end

describe PG::Result, "#rows" do
  it "is an empty 2d array on empty results" do
    if Helper.db_version_gte(9,4)
      rows = $DB.exec("select").rows
      rows.size.should    eq(1)
      rows[0].size.should eq(0)
    end
  end

  it "can handle several types and several rows" do
    rows = $DB.exec(
             {String, PG::NilableString, Bool, Int32},
             "select 'a', 'b', true, 22 union all select '', null, false, 53"
           ).rows
    rows.should eq([{"a", "b", true,  22},
                    {"",  nil, false, 53}])
    [rows[0][0],    rows[1][0]].map(&.length).sum.should eq(1)
    (rows[0][2] && !rows[1][2]).should be_true
    (rows[0][3] <   rows[1][3]).should be_true
  end

  #           name,             sql,              result
  test_decode "undefined",      "'what'",         "what"
  test_decode "text",           "'what'::text",   "what"
  test_decode "empty strings",  "''",             ""
  test_decode "null as nil",    "null",           nil
  test_decode "boolean false",  "false",          false
  test_decode "boolean true",   "true",           true
  test_decode "integer",        "1",              1
  test_decode "float",          "-0.123::float",  -0.123

  if Helper.db_version_gte(9,2)
    test_decode "json",  "'[1,\"a\",true]'::json", [1, "a", true]
    test_decode "json",  "'{\"a\":1}'::json",      {"a" => 1}
  end
  if Helper.db_version_gte(9,4)
    test_decode "jsonb", "'[1,2,3]'::jsonb",       [1, 2, 3]
  end

  test_decode "timestamptz",  "'2015-02-03 16:15:13-01'::timestamptz",
                       Time.new(2015, 2, 3,17,15,13,0, Time::Kind::Utc)

  test_decode "timestamptz",  "'2015-02-03 16:15:14.23-01'::timestamptz",
                       Time.new(2015, 2, 3,17,15,14,230, Time::Kind::Utc)

  test_decode "timestamp",    "'2015-02-03 16:15:15'::timestamp",
                       Time.new(2015, 2, 3,16,15,15,0, Time::Kind::Utc)

  test_decode "date", "'2015-02-03'::date",
               Time.new(2015, 2, 3,0,0,0,0, Time::Kind::Utc)
end

describe PG::Result, "#to_hash" do
  it "represents the rows and fields as a hash" do
    res = $DB.exec("select 'a' as foo, 'b' as bar, true as baz, 1.0 as uhh
                   union all
                   select '', null, false, -3.2")
    res.to_hash.should eq([
      {"foo" => "a", "bar" => "b", "baz" => true,  "uhh" => "1.0"},
      {"foo" => "",  "bar" => nil, "baz" => false, "uhh" => "-3.2"}
    ])
  end

  it "raises if there are columns with the same name" do
    res = $DB.exec("select 'a' as foo, 'b' as foo, 'c' as bar")
    expect_raises { res.to_hash }
  end
end
