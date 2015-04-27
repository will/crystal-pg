module PG
  @[Link(ldflags: "-lpq -I`pg_config --includedir` -L`pg_config --libdir`")]
  lib LibPQ
    alias CChar = UInt8
    struct PGconn   end
    struct PGresult end
    fun connect       = PQconnectdb(conninfo : CChar*)         : PGconn*
    fun exec          = PQexec(conn : PGconn*, query : UInt8*) : PGresult*
    fun result_status = PQresultStatus(res : PGresult*)        : Int32
    fun error_message = PQerrorMessage(conn : PGconn*)         : CChar*

    fun nfields  = PQnfields(res : PGresult*) : Int32
    fun ntuples  = PQntuples(res : PGresult*) : Int32
    fun fname    = PQfname(res : PGresult*, column_number : Int32) : CChar*
    fun getvalue = PQgetvalue(res : PGresult*, row_number : Int32, column_number : Int32) : CChar*
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

