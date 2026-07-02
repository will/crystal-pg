require "../../spec_helper"

describe PG::Replication::ErrorFrame do
  it "decodes severity, message, detail and hint" do
    body = IO::Memory.new
    body << 'S' << "ERROR" << '\0'
    body << 'M' << "boom" << '\0'
    body << 'D' << "the detail" << '\0'
    body << 'H' << "a hint" << '\0'
    body.write_byte 0_u8

    io = IO::Memory.new
    io.write_bytes(body.size.to_i32 + 4, IO::ByteFormat::NetworkEndian) # length prefix
    io.write body.to_slice
    io.rewind

    frame = PG::Replication::ErrorFrame.new(io)
    frame.severity.should eq(PG::Replication::Severity::ERROR)
    frame.message.should eq("boom")
    frame.detail.should eq("the detail")
    frame.hint.should eq("a hint")
  end
end
