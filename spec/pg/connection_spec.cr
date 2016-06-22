require "../spec_helper"
require "uri"
describe PG::Connection, "#initialize" do
  it "raises on bad connections" do
    expect_raises(PQ::ConnectionError) {
      DB.open("postgres://localhost:5433")
    }
  end
end

# describe PG::Connection, "#exec untyped" do
#   it "returns a Result" do
#     res = PG_DB.exec("select 1")
#     res.class.should eq(PG::Result(Array(PG::PGValue)))
#   end

#   it "raises on bad queries" do
#     expect_raises(PQ::PQError) { PG_DB.exec("select nocolumn from notable") }
#   end

#   it "can stream results" do
#     query = "select v as x, v*2 as y from generate_series(1,100) v"
#     x = y = 0
#     fields = nil
#     PG_DB.exec(query) do |row, f|
#       fields = f
#       x += row[0].as(Int32)
#       y += row[1].as(Int32)
#     end.should eq(nil)
#     x.should eq(5050)
#     y.should eq(10100)
#     fields.not_nil!.map(&.name).should eq(%w(x y))
#   end

#   it "returns a Result when create table" do
#     res = PG_DB.exec("create table if not exists test()")
#     res.class.should eq(PG::Result(Array(PG::PGValue)))
#     PG_DB.exec("drop table test")
#   end
# end

# describe PG::Connection, "#exec typed" do
#   it "returns a Result" do
#     res = PG_DB.exec({Int32}, "select 1")
#     res.class.should eq(PG::Result({Int32.class}))
#   end

#   it "can stream results" do
#     query = "select v as x, v*2 as y from generate_series(1,100) v"
#     x = y = 0
#     fields = nil
#     PG_DB.exec({Int32, Int32}, query) do |row, f|
#       fields = f
#       x += row[0]
#       y += row[1]
#     end.should eq(nil)
#     x.should eq(5050)
#     y.should eq(10100)
#     fields.not_nil!.map(&.name).should eq(%w(x y))
#   end

#   it "raises on bad queries" do
#     expect_raises(PQ::PQError) { PG_DB.exec({Int32}, "select nocolumn from notable") }
#   end
# end

# describe PG::Connection, "#exec typed with params" do
#   it "returns a Result" do
#     res = PG_DB.exec({Float64}, "select $1::float * $2::float ", [3.4, -2])
#     res.class.should eq(PG::Result({Float64.class}))
#   end

#   it "can stream results" do
#     query = "select v as x, v*2 as y from generate_series(1,$1) v"
#     x = y = 0
#     fields = nil
#     PG_DB.exec({Int32, Int32}, query, [100]) do |row, f|
#       fields = f
#       x += row[0]
#       y += row[1]
#     end.should eq(nil)
#     x.should eq(5050)
#     y.should eq(10100)
#     fields.not_nil!.map(&.name).should eq(%w(x y))
#   end

#   it "raises on bad queries" do
#     expect_raises(PQ::PQError) { PG_DB.exec("select $1::text from notable", ["hello"]) }
#   end
# end

# describe PG::Connection, "#exec untyped with params" do
#   it "returns a Result" do
#     res = PG_DB.exec("select $1::text, $2::text, $3::text", ["hello", "", "world"])
#     res.class.should eq(PG::Result(Array(PG::PGValue)))
#   end

#   it "can stream results" do
#     query = "select v as x, v*2 as y from generate_series(1,$1) v"
#     x = y = 0
#     fields = nil
#     PG_DB.exec(query, [100]) do |row, f|
#       fields = f
#       x += row[0].as(Int32)
#       y += row[1].as(Int32)
#     end.should eq(nil)
#     x.should eq(5050)
#     y.should eq(10100)
#     fields.not_nil!.map(&.name).should eq(%w(x y))
#   end

#   it "raises on bad queries" do
#     expect_raises(PQ::PQError) { PG_DB.exec("select $1::text from notable", ["hello"]) }
#   end

#   it "can properly encode various types" do
#     time = Time.new(2015, 5, 2, 13, 14, 15, 0, Time::Kind::Utc)
#     date = Time.new(2015, 5, 2, 0, 0, 0, 0, Time::Kind::Utc)
#     slice = Slice(UInt8).new(UInt8[5, 0, 255, 128].to_unsafe, 4)
#     query = "select $1::text, $2::text, $3::int, $4::text, $5::float, $6::timestamptz, $7::date, $8::bool, $9::bytea"
#     param = ["hello", "", 2, nil, -4.23, time, date, true, slice]
#     res = PG_DB.exec(query, param)
#     res.rows.should eq([param])
#   end
# end

# describe PG::Connection, "#exec_all" do
#   it "returns nil" do
#     res = PG_DB.exec_all("select 1; select 2;")
#     res.class.should eq(Nil)
#   end

#   it "raises on bad queries" do
#     expect_raises(PQ::PQError) { PG_DB.exec_all("select 1; select nocolumn from notable;") }
#   end
# end

# describe PG::Connection, "#on_notice" do
#   it "sends notices to on_notice" do
#     last_notice = nil
#     PG_DB.on_notice do |notice|
#       last_notice = notice
#     end

#     PG_DB.exec_all <<-SQL
#       SET client_min_messages TO notice;
#       DO language plpgsql $$
#       BEGIN
#         RAISE NOTICE 'hello, world!';
#       END
#       $$;
#     SQL
#     last_notice.should_not eq(nil)
#     last_notice.to_s.should eq("NOTICE:  hello, world!\n")
#   end
# end

# describe PG::Connection, "#on_notification" do
#   it "does listen/notify" do
#     last_note = nil
#     PG_DB.on_notification { |note| last_note = note }

#     PG_DB.exec("listen somechannel")
#     PG_DB.exec("notify somechannel, 'do a thing'")

#     last_note.not_nil!.channel.should eq("somechannel")
#     last_note.not_nil!.payload.should eq("do a thing")
#   end
# end
