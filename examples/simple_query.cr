#!/usr/bin/env crystal
require "../src/pg"

# A small example on how to use the underlying driver to execute Simple Query messages
# https://www.postgresql.org/docs/current/protocol-flow.html#PROTOCOL-FLOW-SIMPLE-QUERY

class SimpleConnection < PQ::Connection
  def self.connect(conninfo)
    new(conninfo).tap(&.connect)
  end

  # Run a single query using the Postgres Simple Query protocol
  # - Yields each row as an Array(String?)
  # - Returns the row description
  #
  # NOTE: While this protocol supports more than one statement per message,
  # this very basic client implementaiton does not, and will error out on the
  # call expecting the ReadyForQuery frame.
  def sq(query, &) : Array(PQ::Field)
    send_query_message(query)
    fields = case (frame = read)
             when PQ::Frame::RowDescription
               read_all_data_rows { |row| yield row.map { |col| col && String.new col } }
               frame.fields
             when PQ::Frame::CommandComplete, PQ::Frame::EmptyQueryResponse
               [] of PQ::Field
             else
               raise "expected RowDescription or NoData, got #{frame}"
             end

    expect_frame PQ::Frame::ReadyForQuery
    fields
  end

  # ingore any rows in the results
  def sq(query)
    sq(query) { }
  end
end

conn = SimpleConnection.connect PQ::ConnInfo.new

conn.sq("select generate_series(1,10), now()") { |row| p row }
conn.sq("notify foo")
conn.sq("")
conn.sq("select 1/0") { |r| p r } rescue "caught error"
conn.sq("select 'hello', null, 7*2, 'ok'") { |r| p r }

# Will not work:
# conn.sq("select 1; select 2") { |r| p r }
