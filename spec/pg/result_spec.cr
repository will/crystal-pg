require "../spec_helper"

describe PG::Result, "#fields" do
  it "is empty on empty results" do
    if Helper.db_version_gte(9, 4)
      result = DB.exec("select")

      result.fields.size.should eq(0)
    end
  end

  it "is is a list of the fields" do
    result = DB.exec("select 1 as one, 2 as two, 3 as three")
    fields = result.fields
    fields.map(&.name).should eq(["one", "two", "three"])
    fields.map(&.type_oid).should eq([23, 23, 23])
  end
end

describe PG::Result, "#rows" do
  it "is an empty 2d array on empty results" do
    if Helper.db_version_gte(9, 4)
      rows = DB.exec("select").rows
      rows.size.should eq(1)
      rows[0].size.should eq(0)
    end
  end

  it "is an empty array on a no row result set" do
    rows = DB.exec("select 'hi' where false").rows
    rows.size.should eq(0)
  end

  it "can handle several types and several rows" do
    rows = DB.exec(
      {String, String | Nil, Bool, Int32},
      "select 'a', 'b', true, 22 union all select '', null, false, 53"
    ).rows
    rows.should eq([{"a", "b", true, 22},
      {"", nil, false, 53}])
    [rows[0][0], rows[1][0]].map(&.size).sum.should eq(1)
    (rows[0][2] && !rows[1][2]).should be_true
    (rows[0][3] < rows[1][3]).should be_true
  end
end

describe PG::Result, "#to_hash" do
  it "represents the rows and fields as a hash" do
    res = DB.exec("select 'a' as foo, 'b' as bar, true as baz, 1.0::float as uhh
                   union all
                   select '', null, false, -3.2::float")
    res.to_hash.should eq([
      {"foo" => "a", "bar" => "b", "baz" => true, "uhh" => 1.0},
      {"foo" => "", "bar" => nil, "baz" => false, "uhh" => -3.2},
    ])
  end

  it "represents the rows and fields as a hash with typed querying" do
    res = DB.exec({String, String, Bool, Int32},
      "select 'a' as foo, 'b' as bar, true as baz, 10 as uhh
                   union all
                   select '', 'c', false, 20")
    res.to_hash.should eq([
      {"foo" => "a", "bar" => "b", "baz" => true, "uhh" => 10},
      {"foo" => "", "bar" => "c", "baz" => false, "uhh" => 20},
    ])
  end

  it "raises if there are columns with the same name" do
    res = DB.exec("select 'a' as foo, 'b' as foo, 'c' as bar")
    expect_raises { res.to_hash }
  end
end

struct FooBarBaz
  property foo : String?
  property bar : Bool?
  property baz : Int32?

  def initialize(@foo, @bar, @baz)
  end

  def self.from_pg(row, fields)
    foo = bar = baz = nil

    row.zip(fields).each do |pair|
      value = pair.first
      case pair.last.name
      when "foo" then foo = value as String
      when "bar" then bar = value as Bool
      when "baz" then baz = value as Int32
      end
    end

    new(foo, bar, baz)
  end
end

describe PG::Result, "#each" do
  it "iterates rows and passes fields" do
    query = "select 'a' as foo, true as bar, 10 as baz
             union all select '', false, 20"
    data = [] of FooBarBaz
    result = DB.exec(query)
    result.each { |row, fields| data << FooBarBaz.from_pg(row, fields) }

    data.should eq [
      FooBarBaz.new("a", true, 10),
      FooBarBaz.new("", false, 20),
    ]
    typeof(data[0].foo).to_s.should match(/String/)
    typeof(data[0].bar).to_s.should match(/Bool/)
    typeof(data[0].baz).to_s.should match(/Int32/)
  end
end

describe PG::Result, ".stream" do
  it "iterates rows and fields" do
    data = [] of FooBarBaz
    query = "select 'a' as foo, true as bar, 10 as baz
             union all select '', false, 20"

    result = DB.exec(query) do |row, fields|
      data << FooBarBaz.from_pg(row, fields)
    end

    data.should eq [
      FooBarBaz.new("a", true, 10),
      FooBarBaz.new("", false, 20),
    ]
    typeof(data[0].foo).to_s.should match(/String/)
    typeof(data[0].bar).to_s.should match(/Bool/)
    typeof(data[0].baz).to_s.should match(/Int32/)
  end
end
