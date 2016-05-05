require "../spec_helper"

module PG
  class Connection
    getter pq_conn
  end
end

describe "#server_parameters" do
  it "ParameterStatus frames in response to set are handeled" do
    get = ->{ DB.pq_conn.server_parameters["standard_conforming_strings"] }
    get.call.should eq("on")
    DB.exec "set standard_conforming_strings to on"
    get.call.should eq("on")
    DB.exec "set standard_conforming_strings to off"
    get.call.should eq("off")
    DB.exec "set standard_conforming_strings to default"
    get.call.should eq("on")
  end
end
