require "../spec_helper"

private def test_decode(name, select, expected, file = __FILE__, line = __LINE__)
  it name, file, line do
    rows = DB.exec("select #{select}").rows
    rows.size.should eq(1), file, line
    rows.first.size.should eq(1), file, line
    rows.first.first.should eq(expected), file, line
  end
end

describe PG::Decoder do
  #           name,             sql,              result
  test_decode "undefined    ", "'what'       ", "what"
  test_decode "text         ", "'what'::text ", "what"
  test_decode "empty strings", "''           ", ""
  test_decode "null as nil  ", "null         ", nil
  test_decode "boolean false", "false        ", false
  test_decode "boolean true ", "true         ", true
  test_decode "int2 smallint", "1::int2      ", 1
  test_decode "int4 int     ", "1::int4      ", 1
  test_decode "int8 bigint  ", "1::int8      ", 1
  test_decode "float        ", "-0.123::float", -0.123

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
end
