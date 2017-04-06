require "./spec_helper"
require "db/spec"

private def cast(expr, sql_type)
  if sql_type
    "#{expr}::#{sql_type}"
  else
    expr
  end
end

private def bytes(*values)
  Slice(UInt8).new(Array(UInt8).new.push(*values.map(&.to_u8)).to_unsafe, values.size)
end

DB::DriverSpecs(DB::Any).run do
  connection_string DB_URL

  sample_value true, "boolean", "true"
  sample_value false, "boolean", "false"
  sample_value 2, "int4", "2::int4"
  sample_value 1_i64, "int8", "1::int8"
  sample_value "hello", "varchar(256)", "'hello'::varchar"
  sample_value 1.5_f32, "float4", "1.5::float4"
  sample_value 1.5, "float", "1.5::float"

  sample_value Time.utc(2015, 2, 3, 17, 15, 13), "timestamptz", "'2015-02-03 16:15:13-01'::timestamptz"
  sample_value Time.utc(2015, 2, 3, 17, 15, 14, nanosecond: 230_000_000), "timestamptz(3)", "'2015-02-03 16:15:14.23-01'::timestamptz"
  sample_value Time.utc(2015, 2, 3, 16, 15, 15), "timestamp", "'2015-02-03 16:15:15'::timestamp"
  sample_value Time.utc(2015, 2, 3, 0, 0, 0), "date", "'2015-02-03'::date"

  sample_value bytes(0o001, 0o134, 0o176), "bytea", "E'\\\\001\\\\134\\\\176'::bytea"
  sample_value bytes(5, 0, 255, 128), "bytea", "E'\\\\005\\\\000\\\\377\\\\200'::bytea"
  sample_value Bytes.empty, "bytea", "E''::bytea"

  binding_syntax do |index|
    "$#{index}"
  end

  create_table_1column_syntax do |table_name, col1|
    "create table #{table_name} (#{col1.name} #{col1.sql_type} #{col1.null ? "NULL" : "NOT NULL"})"
  end

  create_table_2columns_syntax do |table_name, col1, col2|
    "create table #{table_name} (#{col1.name} #{col1.sql_type} #{col1.null ? "NULL" : "NOT NULL"}, #{col2.name} #{col2.sql_type} #{col2.null ? "NULL" : "NOT NULL"})"
  end

  select_1column_syntax do |table_name, col1|
    "select #{cast(col1.name, col1.sql_type)} from #{table_name}"
  end

  select_2columns_syntax do |table_name, col1, col2|
    "select #{cast(col1.name, col1.sql_type)}, #{cast(col2.name, col2.sql_type)} from #{table_name}"
  end

  select_count_syntax do |table_name|
    "select count(*) from #{table_name}"
  end

  select_scalar_syntax do |expression, sql_type|
    "select #{cast(expression, sql_type)}"
  end

  insert_1column_syntax do |table_name, col, expression|
    "insert into #{table_name} (#{col.name}) values (#{expression})"
  end

  insert_2columns_syntax do |table_name, col1, expr1, col2, expr2|
    "insert into #{table_name} (#{col1.name}, #{col2.name}) values (#{expr1}, #{expr2})"
  end

  drop_table_if_exists_syntax do |table_name|
    "drop table if exists #{table_name}"
  end
end
