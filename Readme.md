# crystal-pg
A Postgres driver for Crystal [![Build Status](https://travis-ci.org/will/crystal-pg.svg?branch=master)](https://travis-ci.org/will/crystal-pg)

## usage
```
DB = PG.connect("postgres://...")
result = DB.exec("select * from table")
result.fields #=> [PG::Result::Field, ...]
result.rows   #=> [[value, ...], ...]

result = DB.exec("select $1::text || ' ' || $2::text", ["hello", "world"])
result.rows #=> [["hello world"]]
```

## Supported Datatypes

- text
- boolean
- int8, int2, int4
- float4, float8
- timestamptz, date, timestamp (but no on should use ts when tstz exists!)


## Todo

- more datatypes (ranges, hstore, json, byeta)
- more info in postgres exceptions
- transaction help
- a lot more


