module PG
  @[Link(ldflags: "-lpq -I`pg_config --includedir` -L`pg_config --libdir`")]
  lib LibPQ
    struct PGconn   end
    struct PGresult end
    fun connect       = PQconnectdb(conninfo : UInt8*) : PGconn*
    fun exec          = PQexec(conn : PGconn*, query : UInt8*) : PGresult*
    fun result_status = PQresultStatus(res : PGresult*) : UInt32
    fun error_message = PQerrorMessage(conn : PGconn*) : UInt8*
  end

  def print_pg_error(conn)
    err = String.new(LibPQ.error_message(conn))
    puts err unless err == ""
  end
end

#conn = LibPQ.connect("postgres:///")
#print_pg_error(conn)
#
#print_pg_error(conn)

