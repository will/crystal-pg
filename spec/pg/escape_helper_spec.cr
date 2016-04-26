require "../spec_helper"

describe PG::Connection, "#escape_literal" do
  assert { DB.escape_literal(%(foo)).should eq(%('foo')) }
  assert { DB.escape_literal(%(this has a \\)).should eq(%( E'this has a \\\\')) }
  assert { DB.escape_literal(%(what's your "name")).should eq(%('what''s your "name"')) }
  assert { DB.escape_literal(%(foo).to_slice).should eq(%('\\x666f6f')) }
  # it "raises on invalid strings" do
  #  expect_raises(PG::ConnectionError) { DB.escape_literal("\u{F4}") }
  # end
end

describe PG::Connection, "#escape_identifier" do
  assert { DB.escape_identifier(%(foo)).should eq(%("foo")) }
  assert { DB.escape_identifier(%(what's \\ your "name")).should eq(%("what's \\ your ""name""")) }
  # it "raises on invalid strings" do
  #  expect_raises(PG::ConnectionError) { DB.escape_identifier("\u{F4}") }
  # end
end
