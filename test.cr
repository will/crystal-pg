require "./src/pg"

conn = PG.connect("postgres:///")
res = conn.exec("insert into what values (now())")
