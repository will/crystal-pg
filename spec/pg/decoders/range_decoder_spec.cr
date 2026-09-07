require "../../spec_helper"

describe PG::Decoders do
  describe "ranges" do
    describe "int4range" do
      test_decode "(lower,upper) - both exclusive", "'(1,10)'::int4range", 2...10 # PostgreSQL canonicalizes discrete ranges to [a,b) form
      test_decode "(lower,upper] - exclusive lower, inclusive upper", "'(1,10]'::int4range", 2...11
      test_decode "[lower,upper) - inclusive lower, exclusive upper", "'[1,10)'::int4range", 1...10
      test_decode "[lower,upper] - both inclusive", "'[1,10]'::int4range", 1...11 # [a,b] becomes [a,b+1) for discrete types
      test_decode "empty range", "'empty'::int4range", 0...0
      test_decode "(-infinity,upper] - infinite lower bound", "'(,10]'::int4range", nil...11
      test_decode "[lower,+infinity) - infinite upper bound", "'[1,)'::int4range", 1...nil
      test_decode "(-infinity,+infinity) - both bounds infinite", "'(,)'::int4range", nil...nil
    end

    describe "int8range" do
      test_decode "(lower,upper) - both exclusive", "'(3000000000,4000000000)'::int8range", 3_000_000_001...4_000_000_000
      test_decode "(lower,upper] - exclusive lower, inclusive upper", "'(3000000000,4000000000]'::int8range", 3_000_000_001...4_000_000_001
      test_decode "[lower,upper) - inclusive lower, exclusive upper", "'[3000000000,4000000000)'::int8range", 3_000_000_000...4_000_000_000
      test_decode "[lower,upper] - both inclusive", "'[3000000000,4000000000]'::int8range", 3_000_000_000...4_000_000_001
      test_decode "empty range", "'empty'::int8range", 0_i64...0_i64
      test_decode "(-infinity,upper] - infinite lower bound", "'(,4000000000]'::int8range", nil...4_000_000_001
      test_decode "[lower,+infinity) - infinite upper bound", "'[3000000000,)'::int8range", 3_000_000_000...nil
      test_decode "(-infinity,+infinity) - both bounds infinite", "'(,)'::int8range", nil...nil
    end

    describe "daterange" do
      test_decode "(lower,upper) - both exclusive", "'(2023-01-01,2023-12-31)'::daterange", Time.utc(2023, 1, 2)...Time.utc(2023, 12, 31)
      test_decode "(lower,upper] - exclusive lower, inclusive upper", "'(2023-01-01,2023-12-31]'::daterange", Time.utc(2023, 1, 2)...Time.utc(2024, 1, 1)
      test_decode "[lower,upper) - inclusive lower, exclusive upper", "'[2023-01-01,2023-12-31)'::daterange", Time.utc(2023, 1, 1)...Time.utc(2023, 12, 31)
      test_decode "[lower,upper] - both inclusive", "'[2023-01-01,2023-12-31]'::daterange", Time.utc(2023, 1, 1)...Time.utc(2024, 1, 1)
      test_decode "empty range", "'empty'::daterange", Time.unix(0)...Time.unix(0)
      test_decode "(-infinity,upper] - infinite lower bound", "'(,2023-12-31]'::daterange", nil...Time.utc(2024, 1, 1)
      test_decode "[lower,+infinity) - infinite upper bound", "'[2023-01-01,)'::daterange", Time.utc(2023, 1, 1)...nil
      test_decode "(-infinity,+infinity) - both bounds infinite", "'(,)'::daterange", nil...nil
    end

    describe "tsrange" do
      test_decode "(lower,upper) - both exclusive", "'(2023-01-01 10:30:00,2023-12-31 15:45:00)'::tsrange", PG::Range.new(Time.utc(2023, 1, 1, 10, 30, 0), Time.utc(2023, 12, 31, 15, 45, 0), lower_inclusive: false)
      test_decode "(lower,upper] - exclusive lower, inclusive upper", "'(2023-01-01 10:30:00,2023-12-31 15:45:00]'::tsrange", PG::Range.new(Time.utc(2023, 1, 1, 10, 30, 0), Time.utc(2023, 12, 31, 15, 45, 0), lower_inclusive: false, upper_inclusive: true)
      test_decode "[lower,upper) - inclusive lower, exclusive upper", "'[2023-01-01 10:30:00,2023-12-31 15:45:00)'::tsrange", Time.utc(2023, 1, 1, 10, 30, 0)...Time.utc(2023, 12, 31, 15, 45, 0)
      test_decode "[lower,upper] - both inclusive", "'[2023-01-01 10:30:00,2023-12-31 15:45:00]'::tsrange", Time.utc(2023, 1, 1, 10, 30, 0)..Time.utc(2023, 12, 31, 15, 45, 0)
      test_decode "empty range", "'empty'::tsrange", Time.unix(0)...Time.unix(0)
      test_decode "(-infinity,upper] - infinite lower bound", "'(,2023-12-31 15:45:00]'::tsrange", nil..Time.utc(2023, 12, 31, 15, 45, 0)
      test_decode "[lower,+infinity) - infinite upper bound", "'[2023-01-01 10:30:00,)'::tsrange", Time.utc(2023, 1, 1, 10, 30, 0)...nil
      test_decode "(-infinity,+infinity) - both bounds infinite", "'(,)'::tsrange", nil...nil

      it "preserves lower-bound exclusivity" do
        lower = Time.utc(2023, 1, 1, 10, 30, 0)
        upper = Time.utc(2023, 12, 31, 15, 45, 0)

        exclusive_lower = PG_DB.query_one "select '(2023-01-01 10:30:00,2023-12-31 15:45:00)'::tsrange", &.read
        inclusive_lower = PG_DB.query_one "select '[2023-01-01 10:30:00,2023-12-31 15:45:00)'::tsrange", &.read

        exclusive_lower.should eq(PG::Range.new(lower, upper, lower_inclusive: false))
        inclusive_lower.should eq(PG::Range.new(lower, upper))
        exclusive_lower.should_not eq(inclusive_lower)
      end
    end

    describe "tstzrange" do
      test_decode "(lower,upper) - both exclusive", "'(2023-01-01 10:30:00+00,2023-12-31 15:45:00+00)'::tstzrange", PG::Range.new(Time.utc(2023, 1, 1, 10, 30, 0), Time.utc(2023, 12, 31, 15, 45, 0), lower_inclusive: false)
      test_decode "(lower,upper] - exclusive lower, inclusive upper", "'(2023-01-01 10:30:00+00,2023-12-31 15:45:00+00]'::tstzrange", PG::Range.new(Time.utc(2023, 1, 1, 10, 30, 0), Time.utc(2023, 12, 31, 15, 45, 0), lower_inclusive: false, upper_inclusive: true)
      test_decode "[lower,upper) - inclusive lower, exclusive upper", "'[2023-01-01 10:30:00+00,2023-12-31 15:45:00+00)'::tstzrange", Time.utc(2023, 1, 1, 10, 30, 0)...Time.utc(2023, 12, 31, 15, 45, 0)
      test_decode "[lower,upper] - both inclusive", "'[2023-01-01 10:30:00+00,2023-12-31 15:45:00+00]'::tstzrange", Time.utc(2023, 1, 1, 10, 30, 0)..Time.utc(2023, 12, 31, 15, 45, 0)
      test_decode "empty range", "'empty'::tstzrange", Time.unix(0)...Time.unix(0)
      test_decode "(-infinity,upper] - infinite lower bound", "'(,2023-12-31 15:45:00+00]'::tstzrange", nil..Time.utc(2023, 12, 31, 15, 45, 0)
      test_decode "[lower,+infinity) - infinite upper bound", "'[2023-01-01 10:30:00+00,)'::tstzrange", Time.utc(2023, 1, 1, 10, 30, 0)...nil
      test_decode "(-infinity,+infinity) - both bounds infinite", "'(,)'::tstzrange", nil...nil
    end

    describe "numrange" do
      test_decode "(lower,upper) - both exclusive", "'(1.5,10.75)'::numrange", PG::Range.new(PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16]), PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16]), lower_inclusive: false)
      test_decode "(lower,upper] - exclusive lower, inclusive upper", "'(1.5,10.75]'::numrange", PG::Range.new(PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16]), PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16]), lower_inclusive: false, upper_inclusive: true)
      test_decode "[lower,upper) - inclusive lower, exclusive upper", "'[1.5,10.75)'::numrange", PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16])...PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16])
      test_decode "[lower,upper] - both inclusive", "'[1.5,10.75]'::numrange", PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16])..PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16])
      test_decode "empty range", "'empty'::numrange", PG::Numeric.new(1_i16, 0_i16, 0_i16, 0_i16, [0_i16])...PG::Numeric.new(1_i16, 0_i16, 0_i16, 0_i16, [0_i16])
      test_decode "(-infinity,upper] - infinite lower bound", "'(,10.75]'::numrange", nil..PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16])
      test_decode "[lower,+infinity) - infinite upper bound", "'[1.5,)'::numrange", PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16])...nil
      test_decode "(-infinity,+infinity) - both bounds infinite", "'(,)'::numrange", nil...nil

      it "preserves lower-bound exclusivity" do
        lower = PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16])
        upper = PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [10_i16, 7500_i16])

        exclusive_lower = PG_DB.query_one "select '(1.5,10.75)'::numrange", &.read
        inclusive_lower = PG_DB.query_one "select '[1.5,10.75)'::numrange", &.read

        exclusive_lower.should eq(PG::Range.new(lower, upper, lower_inclusive: false))
        inclusive_lower.should eq(PG::Range.new(lower, upper))
        exclusive_lower.should_not eq(inclusive_lower)
      end
    end
  end

  if Helper.db_version_gte(14)
    describe "multiranges" do
      describe "int4multirange" do
        test_decode "empty", "'{}'::int4multirange", [] of Range(Int32?, Int32?)
        test_decode "single range", "'{[1,5)}'::int4multirange", [1...5]
        test_decode "multiple ranges", "'{[1,3), [7,10)}'::int4multirange", [1...3, 7...10]
        test_decode "with infinite bounds", "'{(,0), [10,)}'::int4multirange", [nil...0, 10...nil]
      end

      describe "int8multirange" do
        test_decode "empty", "'{}'::int8multirange", [] of Range(Int64?, Int64?)
        test_decode "single range", "'{[1,5)}'::int8multirange", [1_i64...5_i64]
        test_decode "multiple ranges", "'{[1,3), [7,10)}'::int8multirange", [1_i64...3_i64, 7_i64...10_i64]
      end

      describe "datemultirange" do
        test_decode "empty", "'{}'::datemultirange", [] of Range(Time?, Time?)
        test_decode "single range", "'{[2023-01-01,2023-01-05)}'::datemultirange", [Time.utc(2023, 1, 1)...Time.utc(2023, 1, 5)]
        test_decode "multiple ranges", "'{[2023-01-01,2023-01-03), [2023-01-07,2023-01-10)}'::datemultirange", [Time.utc(2023, 1, 1)...Time.utc(2023, 1, 3), Time.utc(2023, 1, 7)...Time.utc(2023, 1, 10)]
      end

      describe "tsmultirange" do
        test_decode "empty", "'{}'::tsmultirange", [] of Range(Time?, Time?)
        test_decode "single range", "'{[2023-01-01 10:30:00,2023-01-01 15:30:00)}'::tsmultirange", [Time.utc(2023, 1, 1, 10, 30, 0)...Time.utc(2023, 1, 1, 15, 30, 0)]
      end

      describe "tstzmultirange" do
        test_decode "empty", "'{}'::tstzmultirange", [] of Range(Time?, Time?)
        test_decode "single range", "'{[2023-01-01 10:30:00+00,2023-01-01 15:30:00+00)}'::tstzmultirange", [Time.utc(2023, 1, 1, 10, 30, 0)...Time.utc(2023, 1, 1, 15, 30, 0)]
      end

      describe "nummultirange" do
        test_decode "empty", "'{}'::nummultirange", [] of Range(PG::Numeric?, PG::Numeric?)
        test_decode "single range", "'{[1.5,5.75)}'::nummultirange", [PG::Numeric.new(2_i16, 0_i16, 0_i16, 1_i16, [1_i16, 5000_i16])...PG::Numeric.new(2_i16, 0_i16, 0_i16, 2_i16, [5_i16, 7500_i16])]
      end
    end
  end
end
