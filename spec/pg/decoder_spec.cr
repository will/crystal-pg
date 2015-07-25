require "../spec_helper"
describe PG::Decoder::StringTimeDecoder, "decode" do
  it "can parse basic dates and times" do
    dec = PG::Decoder::StringTimeDecoder.new

    dec.decode("2014-01-02".cstr).should eq(
       Time.new(2014, 1, 2))

    dec.decode("2014-01-02 18:20:33".cstr).should eq(
       Time.new(2014, 1, 2,18,20,33))
  end

  it "can parse microseconds to miliseconds" do
    dec = PG::Decoder::StringTimeDecoder.new

    dec.decode("2014-01-02 18:20:33.266293".cstr).should eq(
       Time.new(2014, 1, 2,18,20,33,266))

    dec.decode("2014-01-02 18:20:33.266".cstr).should eq(
       Time.new(2014, 1, 2,18,20,33,266))

    dec.decode("2014-01-02 18:20:33.23".cstr).should eq(
       Time.new(2014, 1, 2,18,20,33,230))

    dec.decode("2014-01-02 18:20:33.2".cstr).should eq(
       Time.new(2014, 1, 2,18,20,33,200))
  end

  it "can parse timezone offsets" do
    dec = PG::Decoder::StringTimeDecoder.new

    dec.decode("2015-05-02 18:13:40.765172+00".cstr).should eq(
       Time.new(2015, 5, 2,18,13,40,765))

    dec.decode("2015-05-02 18:13:40.765172-07".cstr).should eq(
       Time.new(2015, 5, 3, 1,13,40,765))

    dec.decode("2015-05-02 18:13:40.765172+07".cstr).should eq(
       Time.new(2015, 5, 2,11,13,40,765))

    dec.decode("2015-05-02 18:13:40-07".cstr).should eq(
       Time.new(2015, 5, 3, 1,13,40,0))

    dec.decode("2015-05-02 18:13:40+07".cstr).should eq(
       Time.new(2015, 5, 2,11,13,40,0))
  end
end

