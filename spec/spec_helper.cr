require "spec"
require "../src/pg"

DB_URL = ENV["DATABASE_URL"]? || "postgres:///"
DB = PG.connect(DB_URL)
