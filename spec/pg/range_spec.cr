require "../spec_helper"
require "../../src/pg/range"

private def assert_roundtrip(x, sql_type, as cls)
  PG_DB.exec("create table test (a #{sql_type})")
  PG_DB.exec("insert into test values ($1)", x)
  value = PG_DB.query_one("select a from test", as: cls)
  value.should eq(x)
ensure
  PG_DB.exec("drop table test") rescue nil
end

describe "PG::Range" do
  describe "Int4Range" do
    it "decodes int4range with inclusive bounds" do
      # PostgreSQL canonicalizes [1,10] to [1,11)
      range = PG::Range(Int32).new(1, 11, true, false)
      assert_roundtrip(range, "int4range", PG::Int4Range)
    end

    it "decodes int4range with exclusive bounds" do
      # PostgreSQL canonicalizes (1,10) to [2,10)
      range = PG::Range(Int32).new(2, 10, true, false)
      assert_roundtrip(range, "int4range", PG::Int4Range)
    end

    it "decodes empty int4range" do
      range = PG::Range(Int32).empty
      assert_roundtrip(range, "int4range", PG::Int4Range)
    end

    it "decodes int4range with infinite bounds" do
      # PostgreSQL canonicalizes [,10) to (,10)
      range = PG::Range(Int32).new(nil, 10, false, false)
      assert_roundtrip(range, "int4range", PG::Int4Range)

      range2 = PG::Range(Int32).new(1, nil, true, false)
      assert_roundtrip(range2, "int4range", PG::Int4Range)
    end
  end

  describe "Int8Range" do
    it "decodes int8range" do
      range = PG::Range(Int64).new(1_i64, 1000000_i64, true, false)
      assert_roundtrip(range, "int8range", PG::Int8Range)
    end
  end

  describe "NumRange" do
    it "decodes numrange" do
      # Test with simpler numerics that PostgreSQL won't change
      PG_DB.exec("create table test (a numrange)")
      PG_DB.exec("insert into test values (numrange(1.0, 10.0))")
      value = PG_DB.query_one("select a from test", as: PG::NumRange)

      value.lower.not_nil!.to_s.should eq("1.0")
      value.upper.not_nil!.to_s.should eq("10.0")
      value.lower_inclusive.should be_true
      value.upper_inclusive.should be_false
      value.empty?.should be_false
    ensure
      PG_DB.exec("drop table test") rescue nil
    end
  end

  describe "TsRange" do
    it "decodes tsrange" do
      t1 = Time.utc(2020, 1, 1, 12, 0, 0)
      t2 = Time.utc(2020, 12, 31, 23, 59, 59)
      range = PG::Range(Time).new(t1, t2, true, true)
      assert_roundtrip(range, "tsrange", PG::TsRange)
    end
  end

  describe "TsTzRange" do
    it "decodes tstzrange" do
      t1 = Time.utc(2020, 1, 1, 12, 0, 0)
      t2 = Time.utc(2020, 12, 31, 23, 59, 59)
      range = PG::Range(Time).new(t1, t2, true, false)
      assert_roundtrip(range, "tstzrange", PG::TsTzRange)
    end
  end

  describe "DateRange" do
    it "decodes daterange" do
      d1 = Time.utc(2020, 1, 1)
      # PostgreSQL canonicalizes [2020-01-01,2020-12-31] to [2020-01-01,2021-01-01)
      d2 = Time.utc(2021, 1, 1)
      range = PG::Range(Time).new(d1, d2, true, false)
      assert_roundtrip(range, "daterange", PG::DateRange)
    end
  end

  describe "to_s" do
    it "formats inclusive range" do
      range = PG::Range(Int32).new(1, 10, true, true)
      range.to_s.should eq("[1,10]")
    end

    it "formats exclusive range" do
      range = PG::Range(Int32).new(1, 10, false, false)
      range.to_s.should eq("(1,10)")
    end

    it "formats mixed bounds" do
      range = PG::Range(Int32).new(1, 10, true, false)
      range.to_s.should eq("[1,10)")
    end

    it "formats empty range" do
      range = PG::Range(Int32).empty
      range.to_s.should eq("empty")
    end

    it "formats infinite ranges" do
      range = PG::Range(Int32).new(nil, 10, true, false)
      range.to_s.should eq("[,10)")

      range2 = PG::Range(Int32).new(1, nil, true, false)
      range2.to_s.should eq("[1,)")
    end
  end
end
