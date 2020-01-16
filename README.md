# crystal-pg
A native, non-blocking Postgres driver for Crystal

[![Build Status](https://circleci.com/gh/will/crystal-pg/tree/master.svg?style=svg)](https://circleci.com/gh/will/crystal-pg/tree/master)


## usage

This driver now uses the `crystal-db` project. Documentation on connecting,
querying, etc, can be found at:

* https://crystal-lang.org/docs/database/
* https://crystal-lang.org/docs/database/connection_pool.html

### shards

Add this to your `shard.yml` and run `shards install`

``` yml
dependencies:
  pg:
    github: will/crystal-pg
```

### Listen/Notify

There are two ways to listen for notifications. For docs on `NOTIFY`, please
read <https://www.postgresql.org/docs/current/static/sql-notify.html>.

1. Any connection can be given a callback to run on notifications. However they
   are only received when other traffic is going on.
2. A special listen-only connection can be established for instant notification
   processing with `PG.connect_listen`.

``` crystal
# see full example in examples/listen_notify.cr
PG.connect_listen("postgres:///", "a", "b") do |n| # connect and  listen on "a" and "b"
  puts "    got: #{n.payload} on #{n.channel}"     # print notifications as they come in
end
```

### Arrays

Crystal-pg supports several popular array types. If you only need a 1
dimensional array, you can cast down to the appropriate Crystal type:

``` crystal
PG_DB.query_one("select ARRAY[1, null, 3]", &.read(Array(Int32?))
# => [1, nil, 3]

PG_DB.query_one("select '{hello, world}'::text[]", &.read(Array(String))
# => ["hello", "world"]
```

### Error Handling
It is possible to catch errors and notifications and pass them along to Crystal for further handling.
```Crystal
DB.connect("postgres:///") do |cnn|
  # Capture and print all exceptions
  cnn.on_notice { |x| puts "pgSQL #{x}" }

  # A function that raises exceptions
  cnn.exec(
    <<-SQL
      CREATE OR REPLACE FUNCTION foo(IN str TEXT)
        RETURNS VOID
        LANGUAGE 'plpgsql'
        AS $$
          BEGIN
            IF str = 'yes' THEN
                    RAISE NOTICE 'Glad we agree!';
            ELSE
              RAISE EXCEPTION 'You know nothing John Snow!';
            END IF;
          END;
        $$;
    SQL
  )

  # Notice handling example
  cnn.exec(
    <<-SQL
      SELECT foo('yes');
    SQL
  )
  # => pgSQL NOTICE: Glad we agree!

  # Exception handling example
  cnn.exec(
    <<-SQL
      SELECT foo('no');
    SQL
  )
  # => pgSQL ERROR: You know nothing John Snow!
  #    Unhandled exception: You know nothing John Snow! (PQ::PQError)
  #     from lib/pg/src/pq/connection.cr:203:7 in 'handle_error'
  #     from lib/pg/src/pq/connection.cr:186:7 in 'handle_async_frames'
  #     from lib/pg/src/pq/connection.cr:162:7 in 'read'
  #     from lib/pg/src/pq/connection.cr:386:18 in 'expect_frame'
  #     from lib/pg/src/pq/connection.cr:370:9 in 'read_next_row_start'
  #     from lib/pg/src/pg/result_set.cr:39:8 in 'move_next'
  #     from lib/pg/src/pg/statement.cr:39:13 in 'perform_exec'
  #     from lib/db/src/db/statement.cr:82:14 in 'perform_exec_and_release'
  #     from lib/db/src/db/statement.cr:68:7 in 'exec:args'
  #     from lib/db/src/db/query_methods.cr:271:7 in 'exec'
  #     from spec/cerebrum_spec.cr:84:3 in '__crystal_main'
  #     from /usr/share/crystal/src/crystal/main.cr:97:5 in 'main_user_code'
  #     from /usr/share/crystal/src/crystal/main.cr:86:7 in 'main'
  #     from /usr/share/crystal/src/crystal/main.cr:106:3 in 'main'
  #     from __libc_start_main
  #     from _start
  #     from ???
```

## Requirements

Crystal-pg is [regularly tested on](https://circleci.com/gh/will/crystal-pg)
the Postgres versions the [Postgres project itself supports](https://www.postgresql.org/support/versioning/).
Since it uses protocol version 3, older versions probably also work but are not guaranteed.

## Supported Datatypes

- text
- boolean
- int8, int4, int2
- float4, float8
- timestamptz, date, timestamp (but no one should use ts when tstz exists!)
- json and jsonb
- uuid
- bytea
- numeric/decimal (1)
- varchar
- regtype
- geo types: point, box, path, lseg, polygon, circle, line
- array types: int8, int4, int2, float8, float4, bool, text, numeric, timestamptz, date, timestamp

1: A note on numeric: In Postgres this type has arbitrary precision. In this
    driver, it is represented as a `PG::Numeric` which retains all precision, but
    if you need to do any math on it, you will probably need to cast it to a
    float first. If you need true arbitrary precision, you can optionally
    require `pg_ext/big_rational` which adds `#to_big_r`, but requires that you
    have LibGMP installed.

