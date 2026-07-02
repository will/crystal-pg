require "../spec_helper"

module PG
  class Connection
    getter connection
  end
end

describe PQ::Connection, "#server_parameters" do
  it "ParameterStatus frames in response to set are handeled" do
    get = -> { PG_DB.using_connection &.connection.server_parameters["standard_conforming_strings"] }
    get.call.should eq("on")
    PG_DB.exec "set standard_conforming_strings to on"
    get.call.should eq("on")
    PG_DB.exec "set standard_conforming_strings to off"
    get.call.should eq("off")
    PG_DB.exec "set standard_conforming_strings to default"
    get.call.should eq("on")
  end
end

describe PQ::Connection do
  it "handles empty queries" do
    PG_DB.exec ""
    PG_DB.query("") { }
    PG_DB.query_one("select 1", &.read).should eq(1)
  end

  it "encodes a multi-byte application_name in the startup packet" do
    # Verify the startup packet is accepted when application_name contains
    # multi-byte UTF-8 characters (bytesize ≠ size; é is 2 bytes in UTF-8).
    DB.open("#{DB_URL}?application_name=café") do |db|
      db.scalar("select 1").should eq(1)
    end
  end
end
