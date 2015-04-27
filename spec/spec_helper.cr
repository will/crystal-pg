require "spec"
require "../src/pg"

DB = PG.connect(ENV["DATABASE_URL"] || "postgres:///")
