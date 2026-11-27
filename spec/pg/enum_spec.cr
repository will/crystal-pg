require "../spec_helper"

private enum Status
  NEW
  PENDING
  COMPLETED
  CANCELED
end

describe PG::ResultSet do
  describe "reading Postgres ENUM types" do
    it "reads into a Crystal enum" do
      type_name = "temp_enum_#{Random::Secure.hex}"
      table_name = "temp_table_#{Random::Secure.hex}"
      PG_DB.using_connection &.exec_all <<-SQL
        CREATE TYPE #{type_name} AS ENUM (
          'new',
          'pending',
          'completed',
          'canceled'
        );
        CREATE TABLE IF NOT EXISTS #{table_name} (
          status #{type_name} NOT NULL
        );
        INSERT INTO #{table_name} (status)
        VALUES
          ('new'),
          ('pending'),
          ('completed'),
          ('canceled')
      SQL

      statuses = PG_DB.query_all "SELECT status FROM #{table_name}", as: Status

      statuses.should contain Status::NEW
      statuses.should contain Status::PENDING
      statuses.should contain Status::COMPLETED
      statuses.should contain Status::CANCELED
    ensure
      PG_DB.using_connection &.exec_all <<-SQL
        DROP TABLE IF EXISTS #{table_name};
        DROP TYPE IF EXISTS #{type_name} CASCADE;
      SQL
    end
  end
end
