module PG
  @[Link(ldflags: "-lpq -L`pg_config --libdir`")]
  lib LibPQ
    # http://www.postgresql.org/docs/9.4/static/libpq-exec.html
    alias CChar = UInt8
    alias CStr  = CChar*
    alias Int   = Int32
    alias Oid   = Int32

    alias PGconn = Void*
    enum ConnStatusType
      CONNECTION_OK, CONNECTION_BAD, CONNECTION_STARTED, CONNECTION_MADE,
      CONNECTION_AWAITING_RESPONSE, CONNECTION_AUTH_OK, CONNECTION_SETENV,
      CONNECTION_SSL_STARTUP, CONNECTION_NEEDED
    end
    fun connect       = PQconnectdb(conninfo : CStr)  : PGconn
    fun status        = PQstatus(conn : PGconn)       : ConnStatusType
    fun finish        = PQfinish(conn : PGconn)       : Void
    fun error_message = PQerrorMessage(conn : PGconn) : CStr
    fun exec          = PQexec(conn : PGconn, query : CStr) : PGresult
    fun exec_params   = PQexecParams(
                          conn          : PGconn  ,
                          query         : CStr    ,
                          n_params      : Int     ,
                          param_types   : Oid*    ,
                          param_values  : CStr*   ,
                          param_lengths : Int*    ,
                          param_formats : Int*    ,
                          result_format : Int
                        ) : PGresult
    fun escape_literal = PQescapeLiteral(conn : PGconn, str : CStr, length : Int) : CStr
    fun escape_identifier = PQescapeIdentifier(conn : PGconn, str : CStr, length : Int) : CStr

    alias PGresult = Void*
    enum ExecStatusType
      PGRES_EMPTY_QUERY, PGRES_COMMAND_OK, PGRES_TUPLES_OK, PGRES_COPY_OUT,
      PGRES_COPY_IN, PGRES_BAD_RESPONSE, PGRES_NONFATAL_ERROR, PGRES_FATAL_ERROR,
      PGRES_COPY_BOTH, PGRES_SINGLE_TUPLE
    end
    fun result_status        = PQresultStatus(res : PGresult) : ExecStatusType
    fun result_error_message = PQresultErrorMessage(res : PGresult) : CStr
    fun clear    = PQclear(res : PGresult )  : Void
    fun nfields  = PQnfields(res : PGresult) : Int
    fun ntuples  = PQntuples(res : PGresult) : Int
    fun fname    = PQfname(res : PGresult, column_number : Int) : CStr
    fun ftype    = PQftype(res : PGresult, column_number : Int) : Int
    fun getvalue = PQgetvalue(res : PGresult, row_number : Int, column_number : Int) : CStr
    fun getlength = PQgetlength(res : PGresult, row_number : Int, column_number : Int) : Int
    fun getisnull = PQgetisnull(res : PGresult, row_number : Int, column_number : Int) : Bool

    fun freemem = PQfreemem(ptr : Void*) : Void
  end
end
