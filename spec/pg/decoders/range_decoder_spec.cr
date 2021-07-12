require "../../spec_helper"

describe PG::Decoders do
  describe "int4range" do
    test_decode "exclusive", "'[10,20)'::int4range", Range.new(10, 20)
    test_decode "exclusive", "'(10,20]'::int4range", Range.new(11, 21)
    test_decode "inclusive", "'[10,20]'::int4range", Range.new(10, 21)
    test_decode "inclusive", "'[10,20)'::int4range", Range.new(10, 20)
    test_decode "negatives", "'[-14,-5)'::int4range", Range.new(-14, -5)
  end
end
