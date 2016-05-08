#!/usr/bin/env crystal
require "readline"
require "../src/pg"

DB = PG.connect(ARGV[0]? || "")

loop do
  query = Readline.readline("# ", true) || ""
  puts
  begin
    DB.exec(query) do |row|
      p row
    end
  rescue e : PQ::PQError
    p e.fields
  rescue e
    p e
  end
  puts
end
