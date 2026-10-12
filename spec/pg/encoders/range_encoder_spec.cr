require "../../spec_helper"

def test_insert_sql_and_read_range(pg_type, pg_value, value)
  it "inserts #{pg_type} with value #{pg_value}" do
    PG_DB.exec "drop table if exists test_table"
    PG_DB.exec "create table test_table (v #{pg_type})"
    PG_DB.exec "insert into test_table values ('#{pg_value}'::#{pg_type})"

    actual_value = PG_DB.query_one "select v from test_table", &.read
    actual_value.should eq(value)
  end
end

def test_insert_object_and_read_range(pg_type, range, value)
  it "inserts #{pg_type} with value #{range}" do
    PG_DB.exec "drop table if exists test_table"
    PG_DB.exec "create table test_table (v #{pg_type})"

    PG_DB.exec "insert into test_table values ($1)", args: [range]

    actual_value = PG_DB.query_one "select v from test_table", &.read

    actual_value.should eq(value)
  end
end

def test_insert_sql_and_read_multirange(pg_type, pg_value, value)
  it "inserts #{pg_type} with value #{pg_value}" do
    PG_DB.exec "drop table if exists test_table"
    PG_DB.exec "create table test_table (v #{pg_type})"
    PG_DB.exec "insert into test_table values ('#{pg_value}'::#{pg_type})"

    actual_value = PG_DB.query_one "select v from test_table", &.read
    actual_value.should eq(value)
  end
end

def test_insert_object_and_read_multirange(pg_type, range, value)
  it "inserts #{pg_type} with value #{range}" do
    PG_DB.exec "drop table if exists test_table"
    PG_DB.exec "create table test_table (v #{pg_type})"
    PG_DB.exec "insert into test_table values ($1)", args: [range]

    actual_value = PG_DB.query_one "select v from test_table", &.read
    actual_value.should eq(value)
  end
end

describe PG::Driver, "encoder" do
  describe "ranges" do
    context "with raw sql" do
      # int4range
      test_insert_sql_and_read_range "int4range", "(1,10)", 2...10
      test_insert_sql_and_read_range "int4range", "(1,10]", 2...11
      test_insert_sql_and_read_range "int4range", "[1,10]", 1...11
      test_insert_sql_and_read_range "int4range", "[1,10)", 1...10
      test_insert_sql_and_read_range "int4range", "empty", 0...0
      test_insert_sql_and_read_range "int4range", "[1,)", 1...nil
      test_insert_sql_and_read_range "int4range", "(,10]", nil...11
      test_insert_sql_and_read_range "int4range", "(,)", nil...nil

      # int8range
      test_insert_sql_and_read_range "int8range", "(1000000000,4000000000)", 1000000001_i64...4000000000_i64
      test_insert_sql_and_read_range "int8range", "(1000000000,4000000000]", 1000000001_i64...4000000001_i64
      test_insert_sql_and_read_range "int8range", "[1000000000,4000000000]", 1000000000_i64...4000000001_i64
      test_insert_sql_and_read_range "int8range", "[1000000000,4000000000)", 1000000000_i64...4000000000_i64
      test_insert_sql_and_read_range "int8range", "empty", 0_i64...0_i64
      test_insert_sql_and_read_range "int8range", "[1000000000,)", 1000000000_i64...nil
      test_insert_sql_and_read_range "int8range", "(,4000000000]", nil...4000000001_i64
      test_insert_sql_and_read_range "int8range", "(,)", nil...nil

      # daterange
      test_insert_sql_and_read_range "daterange", "(2023-01-01,2023-12-31)", Time.utc(2023, 1, 2)...Time.utc(2023, 12, 31)
      test_insert_sql_and_read_range "daterange", "(2023-01-01,2023-12-31]", Time.utc(2023, 1, 2)...Time.utc(2024, 1, 1)
      test_insert_sql_and_read_range "daterange", "[2023-01-01,2023-12-31)", Time.utc(2023, 1, 1)...Time.utc(2023, 12, 31)
      test_insert_sql_and_read_range "daterange", "[2023-01-01,2023-12-31]", Time.utc(2023, 1, 1)...Time.utc(2024, 1, 1)
      test_insert_sql_and_read_range "daterange", "empty", Time.unix(0)...Time.unix(0)
      test_insert_sql_and_read_range "daterange", "(,2023-12-31]", nil...Time.utc(2024, 1, 1)
      test_insert_sql_and_read_range "daterange", "[2023-01-01,)", Time.utc(2023, 1, 1)...nil
      test_insert_sql_and_read_range "daterange", "(,)", nil...nil

      # tsrange
      test_insert_sql_and_read_range "tsrange", "(2023-01-01 10:30:00,2023-12-31 15:45:00)", Time.utc(2023, 1, 1, 10, 30, 0)...Time.utc(2023, 12, 31, 15, 45, 0)
      test_insert_sql_and_read_range "tsrange", "(2023-01-01 10:30:00,2023-12-31 15:45:00]", Time.utc(2023, 1, 1, 10, 30, 0)..Time.utc(2023, 12, 31, 15, 45, 0)
      test_insert_sql_and_read_range "tsrange", "[2023-01-01 10:30:00,2023-12-31 15:45:00)", Time.utc(2023, 1, 1, 10, 30, 0)...Time.utc(2023, 12, 31, 15, 45, 0)
      test_insert_sql_and_read_range "tsrange", "[2023-01-01 10:30:00,2023-12-31 15:45:00]", Time.utc(2023, 1, 1, 10, 30, 0)..Time.utc(2023, 12, 31, 15, 45, 0)
      test_insert_sql_and_read_range "tsrange", "empty", Time.unix(0)...Time.unix(0)
      test_insert_sql_and_read_range "tsrange", "(,2023-12-31 15:45:00]", nil..Time.utc(2023, 12, 31, 15, 45, 0)
      test_insert_sql_and_read_range "tsrange", "[2023-01-01 10:30:00,)", Time.utc(2023, 1, 1, 10, 30, 0)...nil
      test_insert_sql_and_read_range "tsrange", "(,)", nil...nil

      # tstzrange
      test_insert_sql_and_read_range "tstzrange", "(2023-01-01 10:30:00+00,2023-12-31 15:45:00+00)", Time.utc(2023, 1, 1, 10, 30, 0)...Time.utc(2023, 12, 31, 15, 45, 0)
      test_insert_sql_and_read_range "tstzrange", "(2023-01-01 10:30:00+00,2023-12-31 15:45:00+00]", Time.utc(2023, 1, 1, 10, 30, 0)..Time.utc(2023, 12, 31, 15, 45, 0)
      test_insert_sql_and_read_range "tstzrange", "[2023-01-01 10:30:00+00,2023-12-31 15:45:00+00)", Time.utc(2023, 1, 1, 10, 30, 0)...Time.utc(2023, 12, 31, 15, 45, 0)
      test_insert_sql_and_read_range "tstzrange", "[2023-01-01 10:30:00+00,2023-12-31 15:45:00+00]", Time.utc(2023, 1, 1, 10, 30, 0)..Time.utc(2023, 12, 31, 15, 45, 0)
      test_insert_sql_and_read_range "tstzrange", "empty", Time.unix(0)...Time.unix(0)
      test_insert_sql_and_read_range "tstzrange", "[2023-01-01 10:30:00+00,)", Time.utc(2023, 1, 1, 10, 30, 0)...nil
      test_insert_sql_and_read_range "tstzrange", "(,2023-12-31 15:45:00+00]", nil..Time.utc(2023, 12, 31, 15, 45, 0)
      test_insert_sql_and_read_range "tstzrange", "(,)", nil...nil

      # numrange
      test_insert_sql_and_read_range "numrange",
        "(1.5,10.75)",
        PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16])...PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16])
      test_insert_sql_and_read_range "numrange",
        "(1.5,10.75]",
        PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16])..PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16])
      test_insert_sql_and_read_range "numrange",
        "[1.5,10.75)",
        PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16])...PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16])
      test_insert_sql_and_read_range "numrange",
        "[1.5,10.75]",
        PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16])..PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16])
      test_insert_sql_and_read_range "numrange",
        "empty",
        PG::Numeric.new(1_i16, 0_i16, 0_i16, 0_i16, [0_i16])...PG::Numeric.new(1_i16, 0_i16, 0_i16, 0_i16, [0_i16])
      test_insert_sql_and_read_range "numrange",
        "(,10.75]",
        nil..PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16])
      test_insert_sql_and_read_range "numrange",
        "[1.5,)",
        PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16]).as(PG::Numeric?)...nil
      test_insert_sql_and_read_range "numrange",
        "(,)",
        nil...nil
    end

    context "with object" do
      # int4range
      test_insert_object_and_read_range "int4range", 1...10, 1...10
      test_insert_object_and_read_range "int4range", 1..10, 1...11
      test_insert_object_and_read_range "int4range", 1...1, 0...0 # empty range
      test_insert_object_and_read_range "int4range", 1..1, 1...2
      test_insert_object_and_read_range "int4range", nil..nil, nil...nil
      test_insert_object_and_read_range "int4range", nil...nil, 0...0 # empty range
      test_insert_object_and_read_range "int4range", nil...1, nil...1
      test_insert_object_and_read_range "int4range", nil..1, nil...2
      test_insert_object_and_read_range "int4range", 1..nil, 1...nil
      test_insert_object_and_read_range "int4range", 1...nil, 1...nil

      # int8range
      test_insert_object_and_read_range "int8range", 1000000000_i64...4000000000_i64, 1000000000_i64...4000000000_i64
      test_insert_object_and_read_range "int8range", 1000000000_i64..4000000000_i64, 1000000000_i64...4000000001_i64
      test_insert_object_and_read_range "int8range", 0_i64...0_i64, 0_i64...0_i64
      test_insert_object_and_read_range "int8range", ..5000000000, ...5000000001
      test_insert_object_and_read_range "int8range", 5000000000_i64...nil, 5000000000_i64...nil

      # daterange
      test_insert_object_and_read_range "daterange",
        Time.utc(2023, 1, 15)..Time.utc(2023, 12, 31),
        Time.utc(2023, 1, 15)...Time.utc(2024, 1, 1)
      test_insert_object_and_read_range "daterange",
        Time.utc(2023, 1, 15)...Time.utc(2023, 12, 31),
        Time.utc(2023, 1, 15)...Time.utc(2023, 12, 31)
      test_insert_object_and_read_range "daterange",
        Time.utc(2023, 6, 15)..nil,
        Time.utc(2023, 6, 15)...nil
      test_insert_object_and_read_range "daterange",
        Time.utc(2023, 6, 15)...Time.utc(2023, 6, 15),
        Time::UNIX_EPOCH...Time::UNIX_EPOCH

      # tsrange
      test_insert_object_and_read_range "tsrange",
        Time.utc(2023, 1, 1)...Time.utc(2023, 1, 2),
        Time.utc(2023, 1, 1)...Time.utc(2023, 1, 2)
      test_insert_object_and_read_range "tsrange",
        Time.utc(2023, 6, 15, 14, 30, 45, nanosecond: 123456000)...Time.utc(2023, 6, 15, 18, 45, 30, nanosecond: 987654000),
        Time.utc(2023, 6, 15, 14, 30, 45, nanosecond: 123456000)...Time.utc(2023, 6, 15, 18, 45, 30, nanosecond: 987654000)
      test_insert_object_and_read_range "tsrange",
        Time.utc(2023, 1, 1, 10, 30)..Time.utc(2023, 1, 1, 15, 30),
        Time.utc(2023, 1, 1, 10, 30)..Time.utc(2023, 1, 1, 15, 30)
      test_insert_object_and_read_range "tsrange",
        PG::Range.new(Time.utc(2023, 1, 1, 10, 30), Time.utc(2023, 1, 1, 15, 30), lower_inclusive: false),
        PG::Range.new(Time.utc(2023, 1, 1, 10, 30), Time.utc(2023, 1, 1, 15, 30), lower_inclusive: false)
      test_insert_object_and_read_range "tsrange",
        Time.utc(2023, 1, 1)...nil,
        Time.utc(2023, 1, 1)...nil
      test_insert_object_and_read_range "tsrange",
        Time.utc(2023, 1, 1)...Time.utc(2023, 1, 1),
        Time::UNIX_EPOCH...Time::UNIX_EPOCH

      # tstzrange
      test_insert_object_and_read_range "tstzrange",
        Time.local(2023, 1, 1, 10, 30, 0, location: DB_LOCATION)...Time.local(2023, 1, 1, 15, 30, 0, location: DB_LOCATION),
        Time.local(2023, 1, 1, 10, 30, 0, location: DB_LOCATION)...Time.local(2023, 1, 1, 15, 30, 0, location: DB_LOCATION)
      test_insert_object_and_read_range "tstzrange",
        Time.local(2023, 1, 1, 10, 30, 45, nanosecond: 123456000, location: DB_LOCATION)...Time.local(2023, 1, 1, 10, 30, 45, nanosecond: 654321000, location: DB_LOCATION),
        Time.local(2023, 1, 1, 10, 30, 45, nanosecond: 123456000, location: DB_LOCATION)...Time.local(2023, 1, 1, 10, 30, 45, nanosecond: 654321000, location: DB_LOCATION)
      test_insert_object_and_read_range "tstzrange",
        Time.local(2023, 1, 1, 10, 30, 45, nanosecond: 123456000, location: DB_LOCATION)...Time.local(2023, 1, 1, 10, 30, 45, nanosecond: 654321000, location: DB_LOCATION),
        Time.local(2023, 1, 1, 10, 30, 45, nanosecond: 123456000, location: DB_LOCATION)...Time.local(2023, 1, 1, 10, 30, 45, nanosecond: 654321000, location: DB_LOCATION)
      test_insert_object_and_read_range "tstzrange",
        nil...Time.local(2023, 12, 31, 15, 45, 0, location: DB_LOCATION),
        nil...Time.local(2023, 12, 31, 15, 45, 0, location: DB_LOCATION)

      # numrange
      test_insert_object_and_read_range "numrange",
        PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16])...PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16]),
        PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16])...PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16])
      test_insert_object_and_read_range "numrange",
        PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16])...nil,
        PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16])...nil
      test_insert_object_and_read_range "numrange",
        PG::Range.new(
          PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16]),
          PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16]),
          lower_inclusive: false
        ),
        PG::Range.new(
          PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16]),
          PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16]),
          lower_inclusive: false
        )
      test_insert_object_and_read_range "numrange",
        PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [5_i16, 0_i16])...PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [5_i16, 0_i16]),
        PG::Numeric.new(1_i16, 0_i16, 0_i16, 0_i16, [0_i16])...PG::Numeric.new(1_i16, 0_i16, 0_i16, 0_i16, [0_i16])
    end
  end

  if Helper.db_version_gte(14)
    describe "multirange" do
      context "with raw sql" do
        # int4multirange
        test_insert_sql_and_read_multirange "int4multirange",
          "{}",
          [] of Range(Int32?, Int32?)
        test_insert_sql_and_read_multirange "int4multirange",
          "{[1,10)}",
          [1...10]
        test_insert_sql_and_read_multirange "int4multirange",
          "{[1,5), [10,20), [30,40)}",
          [1...5, 10...20, 30...40]

        # int8multirange
        test_insert_sql_and_read_multirange "int8multirange",
          "{[1000000000,2000000000), [3000000000,4000000000)}",
          [1000000000_i64...2000000000_i64, 3000000000_i64...4000000000_i64]

        # datemultirange
        test_insert_sql_and_read_multirange "datemultirange",
          "{[2023-01-01,2023-06-30), [2023-07-01,2023-12-31)}",
          [Time.utc(2023, 1, 1)...Time.utc(2023, 6, 30), Time.utc(2023, 7, 1)...Time.utc(2023, 12, 31)]

        # tsmultirange
        test_insert_sql_and_read_multirange "tsmultirange",
          "{[\"2023-01-01 10:30:00\",\"2023-06-30 15:45:00\"), [\"2023-07-01 08:00:00\",\"2023-12-31 18:30:00\")}",
          [Time.utc(2023, 1, 1, 10, 30)...Time.utc(2023, 6, 30, 15, 45), Time.utc(2023, 7, 1, 8, 0)...Time.utc(2023, 12, 31, 18, 30)]

        # tstzmultirange
        test_insert_sql_and_read_multirange "tstzmultirange",
          "{[\"2023-01-01 10:30:00+00\",\"2023-06-30 15:45:00+00\"), [\"2023-07-01 08:00:00+00\",\"2023-12-31 18:30:00+00\")}",
          [
            Time.utc(2023, 1, 1, 10, 30).in(DB_LOCATION)...Time.utc(2023, 6, 30, 15, 45).in(DB_LOCATION),
            Time.utc(2023, 7, 1, 8, 0).in(DB_LOCATION)...Time.utc(2023, 12, 31, 18, 30).in(DB_LOCATION),
          ]

        # nummultirange
        test_insert_sql_and_read_multirange "nummultirange",
          "{[1.5,10.75), [20.25,99.99)}",
          [
            PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16])...PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16]),
            PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [20_i16, 2500_i16])...PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [99_i16, 9900_i16]),
          ]
      end

      context "with object" do
        # int4multirange
        test_insert_object_and_read_multirange "int4multirange",
          [] of Range(Int32?, Int32?),
          [] of Range(Int32?, Int32?)
        test_insert_object_and_read_multirange "int4multirange",
          [1...10],
          [1...10]
        test_insert_object_and_read_multirange "int4multirange",
          [1...5, 10...20, 30...40],
          [1...5, 10...20, 30...40]
        test_insert_object_and_read_multirange "int4multirange",
          [nil...100, 200...nil],
          [nil...100, 200...nil]
        test_insert_object_and_read_multirange "int4multirange",
          [1..10, 20...30, 40..50],
          [1...11, 20...30, 40...51]
        test_insert_object_and_read_multirange "int4multirange",
          [1...5, 10...10, 20...30],
          [1...5, 20...30]
        test_insert_object_and_read_multirange "int4multirange",
          [1...5, 10...15, nil...0, 100..nil],
          [...0, 1...5, 10...15, 100...]

        # int8multirange
        test_insert_object_and_read_multirange "int8multirange",
          [] of Range(Int64?, Int64?),
          [] of Range(Int64?, Int64?)
        test_insert_object_and_read_multirange "int8multirange",
          [1000000000_i64...2000000000_i64],
          [1000000000_i64...2000000000_i64]
        test_insert_object_and_read_multirange "int8multirange",
          [1000000000_i64...2000000000_i64, 3000000000_i64...4000000000_i64],
          [1000000000_i64...2000000000_i64, 3000000000_i64...4000000000_i64]
        test_insert_object_and_read_multirange "int8multirange",
          [nil...1000000000_i64, 5000000000_i64...nil],
          [nil...1000000000_i64, 5000000000_i64...nil]
        test_insert_object_and_read_multirange "int8multirange",
          [1000000000_i64..2000000000_i64, 3000000000_i64...4000000000_i64],
          [1000000000_i64...2000000001_i64, 3000000000_i64...4000000000_i64]

        # datemultirange
        test_insert_object_and_read_multirange "datemultirange",
          [] of Range(Time?, Time?),
          [] of Range(Time?, Time?)
        test_insert_object_and_read_multirange "datemultirange",
          [Time.utc(2023, 1, 1)...Time.utc(2023, 6, 30)],
          [Time.utc(2023, 1, 1)...Time.utc(2023, 6, 30)]
        test_insert_object_and_read_multirange "datemultirange",
          [Time.utc(2023, 1, 1)...Time.utc(2023, 6, 30), Time.utc(2023, 7, 1)...Time.utc(2023, 12, 31)],
          [Time.utc(2023, 1, 1)...Time.utc(2023, 6, 30), Time.utc(2023, 7, 1)...Time.utc(2023, 12, 31)]
        test_insert_object_and_read_multirange "datemultirange",
          [Time.utc(2023, 1, 1)..Time.utc(2023, 6, 29), Time.utc(2023, 7, 1)..Time.utc(2023, 12, 31)],
          [Time.utc(2023, 1, 1)...Time.utc(2023, 6, 30), Time.utc(2023, 7, 1)...Time.utc(2024, 1, 1)]
        test_insert_object_and_read_multirange "datemultirange",
          [nil...Time.utc(2023, 6, 30), Time.utc(2023, 7, 1)...nil],
          [nil...Time.utc(2023, 6, 30), Time.utc(2023, 7, 1)...nil]

        # tsmultirange
        test_insert_object_and_read_multirange "tsmultirange",
          [] of Range(Time?, Time?),
          [] of Range(Time?, Time?)
        test_insert_object_and_read_multirange "tsmultirange",
          [Time.utc(2023, 1, 1, 10, 30)...Time.utc(2023, 6, 30, 15, 45)],
          [Time.utc(2023, 1, 1, 10, 30)...Time.utc(2023, 6, 30, 15, 45)]
        test_insert_object_and_read_multirange "tsmultirange",
          [Time.utc(2023, 1, 1, 10, 30)...Time.utc(2023, 6, 30, 15, 45), Time.utc(2023, 7, 1, 8, 0)...Time.utc(2023, 12, 31, 18, 30)],
          [Time.utc(2023, 1, 1, 10, 30)...Time.utc(2023, 6, 30, 15, 45), Time.utc(2023, 7, 1, 8, 0)...Time.utc(2023, 12, 31, 18, 30)]
        test_insert_object_and_read_multirange "tsmultirange",
          [Time.utc(2023, 1, 1, 10, 30)..Time.utc(2023, 6, 30, 15, 45), Time.utc(2023, 7, 1, 8, 0)..Time.utc(2023, 12, 31, 18, 30)],
          [Time.utc(2023, 1, 1, 10, 30)..Time.utc(2023, 6, 30, 15, 45), Time.utc(2023, 7, 1, 8, 0)..Time.utc(2023, 12, 31, 18, 30)]
        test_insert_object_and_read_multirange "tsmultirange",
          [nil...Time.utc(2023, 6, 30, 15, 45), Time.utc(2023, 7, 1, 8, 0)...nil],
          [nil...Time.utc(2023, 6, 30, 15, 45), Time.utc(2023, 7, 1, 8, 0)...nil]

        # tstzmultirange
        test_insert_object_and_read_multirange "tstzmultirange",
          [] of Range(Time?, Time?),
          [] of Range(Time?, Time?)
        test_insert_object_and_read_multirange "tstzmultirange",
          [Time.local(2023, 1, 1, 10, 30, location: DB_LOCATION)...Time.local(2023, 6, 30, 15, 45, location: DB_LOCATION)],
          [Time.local(2023, 1, 1, 10, 30, location: DB_LOCATION)...Time.local(2023, 6, 30, 15, 45, location: DB_LOCATION)]
        test_insert_object_and_read_multirange "tstzmultirange",
          [
            Time.local(2023, 1, 1, 10, 30, location: DB_LOCATION)...Time.local(2023, 6, 30, 15, 45, location: DB_LOCATION),
            Time.local(2023, 7, 1, 8, 0, location: DB_LOCATION)...Time.local(2023, 12, 31, 18, 30, location: DB_LOCATION),
          ],
          [
            Time.local(2023, 1, 1, 10, 30, location: DB_LOCATION)...Time.local(2023, 6, 30, 15, 45, location: DB_LOCATION),
            Time.local(2023, 7, 1, 8, 0, location: DB_LOCATION)...Time.local(2023, 12, 31, 18, 30, location: DB_LOCATION),
          ]
        test_insert_object_and_read_multirange "tstzmultirange",
          [nil...Time.local(2023, 6, 30, 15, 45, location: DB_LOCATION), Time.local(2023, 7, 1, 8, 0, location: DB_LOCATION)...nil],
          [nil...Time.local(2023, 6, 30, 15, 45, location: DB_LOCATION), Time.local(2023, 7, 1, 8, 0, location: DB_LOCATION)...nil]

        # nummultirange
        test_insert_object_and_read_multirange "nummultirange",
          [] of Range(PG::Numeric?, PG::Numeric?),
          [] of Range(PG::Numeric?, PG::Numeric?)
        test_insert_object_and_read_multirange "nummultirange",
          [PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16])...PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16])],
          [PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16])...PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16])]
        test_insert_object_and_read_multirange "nummultirange",
          [
            PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16])...PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16]),
            PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [20_i16, 2500_i16])...PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [99_i16, 9900_i16]),
          ],
          [
            PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16])...PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16]),
            PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [20_i16, 2500_i16])...PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [99_i16, 9900_i16]),
          ]
        test_insert_object_and_read_multirange "nummultirange",
          [nil...PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16]), PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [20_i16, 2500_i16])...nil],
          [nil...PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16]), PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [20_i16, 2500_i16])...nil]
      end
    end
  end
end
