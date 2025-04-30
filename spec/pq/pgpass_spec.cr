require "../spec_helper"
require "../../src/pq/conninfo"
require "../../src/pq/pgpass"
require "log/spec"

def create_empty_pgpass_file(&)
  tempfile = File.tempfile("pgpass")
  begin
    File.chmod(tempfile.path, 0o0600)
    yield tempfile.path
  ensure
    tempfile.delete
  end
end

def create_valid_pgpass_file(&)
  create_empty_pgpass_file do |filename|
    File.write(filename, <<-PGPASS)
host:1:database:user:pass
*:1:database:user:pass2
*:*:database:user:pass3
*:*:*:user:pass4
*:*:*:*:pass5
PGPASS
    yield filename
  end
end

def create_invalid_pgpass_file(&)
  create_empty_pgpass_file do |filename|
    File.write(filename, "host:1:database:user")
    yield filename
  end
end

describe PQ::PgPass, ".parsing" do
  it "parses a proper pgpass file" do
    env_var_bubble do
      create_valid_pgpass_file do |filename|
        ENV["PGPASSFILE"] = filename
        ci = PQ::ConnInfo.from_conninfo_string("postgres://user@host:1/database")
        ci.password.should eq("pass")
        ci = PQ::ConnInfo.from_conninfo_string("postgres://user@host2:1/database")
        ci.password.should eq("pass2")
        ci = PQ::ConnInfo.from_conninfo_string("postgres://user@host2:2/database")
        ci.password.should eq("pass3")
        ci = PQ::ConnInfo.from_conninfo_string("postgres://user@host2:2/database2")
        ci.password.should eq("pass4")
        ci = PQ::ConnInfo.from_conninfo_string("postgres://user2@host:2/database2")
        ci.password.should eq("pass5")
      end
    end
  end

  it "refuses to handle a pgpass file with improper permissions" do
    env_var_bubble do
      create_valid_pgpass_file do |filename|
        File.chmod(filename, 0o0700)
        ENV["PGPASSFILE"] = filename
        Log.capture("pg") {
          ci = PQ::ConnInfo.from_conninfo_string("postgres://")
        }.itself
          .check(:warn, "Cannot use pgpass file - permissions are inappropriate must be 0600 or less")
          .empty
      end
    end
  end

  it "gracefully handles an inproper pgpass file" do
    env_var_bubble do
      create_invalid_pgpass_file do |filename|
        ENV["PGPASSFILE"] = filename
        Log.capture("pg") {
          ci = PQ::ConnInfo.from_conninfo_string("postgres://")
        }.itself
          .check(:warn, "PGPass file does not appear to be properly formatted - errors may occur")
          .empty
      end
    end
  end
end
