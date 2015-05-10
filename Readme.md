# crystal-pg
A Postgres driver for Crystal [![Build Status](https://travis-ci.org/will/crystal-pg.svg?branch=master)](https://travis-ci.org/will/crystal-pg)

## usage
``` crystal
DB = PG.connect("postgres://...")
result = DB.exec("select * from table")
result.fields  #=> [PG::Result::Field, …]
result.rows    #=> [[value, …], …]
result.to_hash #=> [{"field1" => value, …}, …]

result = DB.exec("select $1::text || ' ' || $2::text", ["hello", "world"])
result.rows #=> [["hello world"]]
```

## Requirements

Crystal-pg is [tested on](https://travis-ci.org/will/crystal-pg) Postgres versions 9.1 through 9.4. Since it is based on libpq, older versions probably also work but are not guaranteed.

Linking requires that the `pg_config` binary is in your `$PATH` and returns correct results for `pg_config --includedir` and `pg_config --libdir`.

## Supported Datatypes

- text
- boolean
- int8, int2, int4
- float4, float8
- timestamptz, date, timestamp (but no one should use ts when tstz exists!)
- json and jsonb


## Todo

- more datatypes (ranges, hstore, byeta)
- more info in postgres exceptions
- transaction help
- a lot more


