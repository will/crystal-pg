module PG
  @[Link(ldflags: "-lpq -I`pg_config --includedir` -L`pg_config --libdir`")]
  lib LibPQ
    # http://www.postgresql.org/docs/9.4/static/libpq-exec.html
    alias CChar = UInt8
    alias Int   = Int32

    struct PGconn   end
    enum ConnStatusType
      CONNECTION_OK,
      CONNECTION_BAD
    end
    fun connect       = PQconnectdb(conninfo : CChar*) : PGconn*
    fun status        = PQstatus(conn : PGconn*)       : ConnStatusType
    fun finish        = PQfinish(conn : PGconn*)       : Void
    fun error_message = PQerrorMessage(conn : PGconn*) : CChar*
    fun exec          = PQexec(conn : PGconn*, query : UInt8*) : PGresult*

    struct PGresult end
    fun result_status = PQresultStatus(res : PGresult*) : Int
    fun clear    = PQclear(res : PGresult* )  : Void
    fun nfields  = PQnfields(res : PGresult*) : Int
    fun ntuples  = PQntuples(res : PGresult*) : Int
    fun fname    = PQfname(res : PGresult*, column_number : Int) : CChar*
    fun ftype    = PQftype(res : PGresult*, column_number : Int) : Int
    fun getvalue = PQgetvalue(res : PGresult*, row_number : Int, column_number : Int) : CChar*
    fun getisnull = PQgetisnull(res : PGresult*, row_number : Int, column_number : Int) : Bool
  end

  def print_pg_error(conn)
    err = String.new(LibPQ.error_message(conn))
    puts err unless err == ""
  end
end
