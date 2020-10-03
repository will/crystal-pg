require "../../spec_helper"

describe PG::Decoders do
  # empty ranges
  test_decode "int4range    ", "'(5, 5)'::int4range", 0..0
  test_decode "int4range    ", "'[5, 5)'::int4range", 0..0
  test_decode "int8range    ", "'(5, 5)'::int8range", 0_i64..0_i64
  test_decode "int8range    ", "'[5, 5)'::int8range", 0_i64..0_i64
  test_decode "daterange    ", "'(2015-02-03, 2015-02-03)'::daterange", (Time.utc(1970, 1, 1)..Time.utc(1970, 1, 1))

  test_decode "int4range    ", "'[4, 8]'::int4range", 4...9
  test_decode "int4range    ", "'[4, 8)'::int4range", 4...8
  test_decode "int4range    ", "'(4, 8]'::int4range", 5...9
  test_decode "int4range    ", "'(4, 8)'::int4range", 5...8

  lower = PG::Numeric.new(ndigits: 1, weight: 0, sign: PG::Numeric::Sign::Pos.value, dscale: 0, digits: [1] of Int16)
  upper = PG::Numeric.new(ndigits: 1, weight: 0, sign: PG::Numeric::Sign::Pos.value, dscale: 0, digits: [3] of Int16)
  test_decode "numrange     ", "'[1, 3)'::numrange", lower...upper

  test_decode "daterange    ", "'[2015-02-03, 2015-02-04)'::daterange", (Time.utc(2015, 2, 3)...Time.utc(2015, 2, 4))
  test_decode "tstzrange    ", "'[2015-02-03 16:15:13-01, 2015-02-03 16:15:14-01)'::tstzrange", (Time.utc(2015, 2, 3, 17, 15, 13)...Time.utc(2015, 2, 3, 17, 15, 14))
  test_decode "tsrange      ", "'[2015-02-03 16:15:13, 2015-02-03 16:15:14)'::tsrange", (Time.utc(2015, 2, 3, 16, 15, 13)...Time.utc(2015, 2, 3, 16, 15, 14))
end



  # test_decode "int4range    ", "'(4,50]'::int4range", 4...4
  # test_decode "int4range    ", "'(4,50)'::int4range", 4...4
  # test_decode "int4range    ", "'(0,0)'::int4range", 4...4
  # test_decode "int4range    ", "'(,10)'::int4range", 4...4
  # test_decode "int4range    ", "'(10,)'::int4range", 4...4
  # test_decode "int4range    ", "'[,50]'::int4range", 4...4
  # test_decode "int4range    ", "'[,50)'::int4range", 4...4
  # test_decode "int4range    ", "'(,50]'::int4range", 4...4
  # test_decode "int4range    ", "'(,50)'::int4range", 4...4
  # test_decode "int4range    ", "'[4,]'::int4range", 4...4
  # test_decode "int4range    ", "'[4,)'::int4range", 4...4
  # test_decode "int4range    ", "'(4,]'::int4range", 4...4
  # test_decode "int4range    ", "'(4,)'::int4range", 4...4
  #test_decode "int4range    ", "'(,)'::int4range", 4...4
