require "../spec_helper"
describe PG::TimeDecoder, "decode" do
  it "can parse basic dates and times" do
    dec = PG::TimeDecoder.new

    dec.decode("2014-01-02".cstr).should eq(
       Time.new(2014,01,02))

    dec.decode("2014-01-02 18:20:33".cstr).should eq(
       Time.new(2014,01,02,18,20,33))

    dec.decode("2014-01-02 18:20:33.266293".cstr).should eq(
       Time.new(2014,01,02,18,20,33,266))

    dec.decode("2014-01-02 18:20:33.23".cstr).should eq(
       Time.new(2014,01,02,18,20,33,230))

    dec.decode("2014-01-02 18:20:33.2".cstr).should eq(
       Time.new(2014,01,02,18,20,33,200))

  end
end

