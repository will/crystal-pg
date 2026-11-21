require "../spec_helper"

describe PG::Range do
  describe "#to_crystal_range" do
    it "converts to a Crystal range" do
      PG::Range.new(1, 2, lower_inclusive: true, upper_inclusive: true)
        .to_crystal_range
        .should eq 1..2
      PG::Range.new(1, 2, lower_inclusive: true, upper_inclusive: false)
        .to_crystal_range
        .should eq 1...2
    end

    it "raises if the PG::Range excludes the lower end" do
      range = PG::Range.new(1, 2, lower_inclusive: false, upper_inclusive: false)
      expect_raises PG::Error, /excludes the lower bound/ do
        range.to_crystal_range
      end
    end
  end
end
