require "spec"
require "../src/pg"

DB = PG.connect("postgres:///")
