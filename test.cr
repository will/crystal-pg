require "./src/pg"

conn = PG.connect("postgres:///")
res = conn.exec("insert into what values (now())")
p res.fields
p res.rows

res = conn.exec("select *, 'yes' from what")
p res.fields
p res.rows
