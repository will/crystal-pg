module PG
  @[Link(ldflags: "-lpq -I`pg_config --includedir` -L`pg_config --libdir`")]
  lib LibPQ
    # http://www.postgresql.org/docs/9.4/static/libpq-exec.html
    alias CChar = UInt8
    alias Int   = Int32

    struct PGconn   end
    enum ConnStatusType
      CONNECTION_OK, CONNECTION_BAD, CONNECTION_STARTED, CONNECTION_MADE,
      CONNECTION_AWAITING_RESPONSE, CONNECTION_AUTH_OK, CONNECTION_SETENV,
      CONNECTION_SSL_STARTUP, CONNECTION_NEEDED
    end
    fun connect       = PQconnectdb(conninfo : CChar*) : PGconn*
    fun status        = PQstatus(conn : PGconn*)       : ConnStatusType
    fun finish        = PQfinish(conn : PGconn*)       : Void
    fun error_message = PQerrorMessage(conn : PGconn*) : CChar*
    fun exec          = PQexec(conn : PGconn*, query : UInt8*) : PGresult*

    struct PGresult end
    enum ExecStatusType
      PGRES_EMPTY_QUERY, PGRES_COMMAND_OK, PGRES_TUPLES_OK, PGRES_COPY_OUT,
      PGRES_COPY_IN, PGRES_BAD_RESPONSE, PGRES_NONFATAL_ERROR, PGRES_FATAL_ERROR,
      PGRES_COPY_BOTH, PGRES_SINGLE_TUPLE
    end
    fun result_status        = PQresultStatus(res : PGresult*) : ExecStatusType
    fun result_error_message = PQresultErrorMessage(res : PGresult*) : CChar*
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
