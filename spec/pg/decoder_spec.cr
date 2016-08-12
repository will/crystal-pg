require "../spec_helper"

private def test_decode(name, select, expected, file = __FILE__, line = __LINE__)
  it name, file, line do
    rows = DB.exec("select #{select}").rows
    rows.size.should eq(1), file, line
    rows.first.size.should eq(1), file, line
    rows.first.first.should eq(expected), file, line
  end
end

describe PG::Decoders do
  #           name,             sql,              result
  test_decode "undefined    ", "'what'       ", "what"
  test_decode "text         ", "'what'::text ", "what"
  test_decode "varchar      ", "'wh'::varchar", "wh"
  test_decode "empty strings", "''           ", ""
  test_decode "null as nil  ", "null         ", nil
  test_decode "boolean false", "false        ", false
  test_decode "boolean true ", "true         ", true
  test_decode "int2 smallint", "1::int2      ", 1
  test_decode "int4 int     ", "1::int4      ", 1
  test_decode "int8 bigint  ", "1::int8      ", 1
  test_decode "float        ", "-0.123::float", -0.123
  test_decode "regtype      ", "pg_typeof(3) ", 23

  test_decode "double prec.", "'35.03554004971999'::float8", 35.03554004971999
  test_decode "flot prec.", "'0.10000122'::float4", 0.10000122_f32

  test_decode "bytea", "E'\\\\001\\\\134\\\\176'::bytea",
    Slice(UInt8).new(UInt8[0o001, 0o134, 0o176].to_unsafe, 3)
  test_decode "bytea", "E'\\\\005\\\\000\\\\377\\\\200'::bytea",
    Slice(UInt8).new(UInt8[5, 0, 255, 128].to_unsafe, 4)
  test_decode "bytea empty", "E''::bytea",
    Slice(UInt8).new(UInt8[].to_unsafe, 0)

  test_decode "uuid", "'7d61d548124c4b38bc05cfbb88cfd1d1'::uuid",
    "7d61d548-124c-4b38-bc05-cfbb88cfd1d1"
  test_decode "uuid", "'7d61d548-124c-4b38-bc05-cfbb88cfd1d1'::uuid",
    "7d61d548-124c-4b38-bc05-cfbb88cfd1d1"

  if Helper.db_version_gte(9, 2)
    test_decode "json", %('[1,"a",true]'::json), JSON.parse(%([1,"a",true]))
    test_decode "json", %('{"a":1}'::json), JSON.parse(%({"a":1}))
  end
  if Helper.db_version_gte(9, 4)
    test_decode "jsonb", "'[1,2,3]'::jsonb", JSON.parse("[1,2,3]")
  end

  test_decode "timestamptz", "'2015-02-03 16:15:13-01'::timestamptz",
    Time.new(2015, 2, 3, 17, 15, 13, 0, Time::Kind::Utc)

  test_decode "timestamptz", "'2015-02-03 16:15:14.23-01'::timestamptz",
    Time.new(2015, 2, 3, 17, 15, 14, 230, Time::Kind::Utc)

  test_decode "timestamp", "'2015-02-03 16:15:15'::timestamp",
    Time.new(2015, 2, 3, 16, 15, 15, 0, Time::Kind::Utc)

  test_decode "date", "'2015-02-03'::date",
    Time.new(2015, 2, 3, 0, 0, 0, 0, Time::Kind::Utc)

  it "numeric" do
    x = ->(q : String) do
      DB.exec({PG::Numeric}, "select '#{q}'::numeric").rows.first.first
    end
    x.call("1.3").to_f.should eq(1.3)
    x.call("nan").nan?.should be_true
  end

  test_decode "array", "ARRAY[1]", [1]
  test_decode "array", "ARRAY[1,2]", [1,2]
  test_decode "array", "ARRAY[ARRAY[9,8],ARRAY[7,6]] ", [[1,2],[3,4]]
  test_decode "array", "'{{{1,2},{3,3}},{{2,5},{4,3}}}'::integer[]", [[1,2],[3,4]]
  exit
  test_decode "array", "ARRAY[1, null] ", [1, nil]
  test_decode "array", "('[10:12]={1,2,3}'::integer[])", 10
#  test_decode "int array ", "ARRAY[1,2,3,4,5,6,7]", [1, 2, 3, 4, 5, 6, 7]

  test_decode "xml", "'<json>false</json>'::xml", "<json>false</json>"
  test_decode "char", %('c'::"char"), 'c'
  test_decode "bpchar", %('c'::char), "c"
  test_decode "bpchar", %('c'::char(5)), "c    "
  test_decode "name", %('hi'::name), "hi"
  test_decode "oid", %(2147483648::oid), 2147483648_u32
  test_decode "point", "'(1.2,3.4)'::point", PG::Geo::Point.new(1.2, 3.4)
  test_decode "line ", "'(1,2,3,4)'::line ", PG::Geo::Line.new(1.0, -1.0, 1.0)
  test_decode "line ", "'1,2,3'::circle   ", PG::Geo::Circle.new(1.0, 2.0, 3.0)
  test_decode "lseg ", "'(1,2,3,4)'::lseg ", PG::Geo::LineSegment.new(1.0, 2.0, 3.0, 4.0)
  test_decode "box  ", "'(1,2,3,4)'::box  ", PG::Geo::Box.new(3.0, 4.0, 1.0, 2.0)
  test_decode "path ", "'(1,2,3,4)'::path ", PG::Geo::Path.new([PG::Geo::Point.new(1.0, 2.0), PG::Geo::Point.new(3.0, 4.0)], closed: true)
  test_decode "path ", "'[1,2,3,4,5,6]'::path", PG::Geo::Path.new([PG::Geo::Point.new(1.0, 2.0), PG::Geo::Point.new(3.0, 4.0), PG::Geo::Point.new(5.0, 6.0)], closed: false)
  test_decode "polygon", "'1,2,3,4,5,6'::polygon", [PG::Geo::Point.new(1.0, 2.0), PG::Geo::Point.new(3.0, 4.0), PG::Geo::Point.new(5.0, 6.0)]
end
