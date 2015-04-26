@[Link(ldflags: "-lpq -I`pg_config --includedir` -L`pg_config --libdir`")]
lib LibPQ
  struct PGconn   end
  struct PGresult end
  fun connect       = PQconnectdb(conninfo : UInt8*) : PGconn*
  fun exec          = PQexec(conn : PGconn*, query : UInt8*) : PGresult*
  fun error_message = PQerrorMessage(conn : PGconn*) : UInt8*
end

conn = LibPQ.connect("postgres:///")
puts String.new(LibPQ.error_message(conn))

res = LibPQ.exec(conn, "insert into what values (now())")
puts String.new(LibPQ.error_message(conn))

