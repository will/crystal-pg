require "../spec_helper"

describe PG::Connection, "#initialize" do
  it "raises on bad connections" do
    expect_raises(DB::ConnectionRefused) {
      DB.open("postgres://localhost:5433")
    }
  end
end

describe PG::Connection, "#on_notice" do
  it "sends notices to on_notice" do
    last_notice = nil
    PG_DB.using_connection do |conn|
      conn.on_notice do |notice|
        last_notice = notice
      end
    end

    PG_DB.using_connection do |conn|
      conn.exec_all <<-SQL
        SET client_min_messages TO notice;
        DO language plpgsql $$
        BEGIN
          RAISE NOTICE 'hello, world!';
        END
        $$;
      SQL
    end

    last_notice.should_not eq(nil)
    last_notice.to_s.should eq("NOTICE:  hello, world!\n")
  end
end

describe PG::Connection, "#on_notification" do
  it "does listen/notify within same connection" do
    last_note = nil
    with_db do |db|
      db.using_connection do |conn|
        conn.on_notification { |note| last_note = note }

        conn.exec("listen somechannel")
        conn.exec("notify somechannel, 'do a thing'")
      end
    end

    last_note.not_nil!.channel.should eq("somechannel")
    last_note.not_nil!.payload.should eq("do a thing")
  end
end

describe PG, "#listen" do
  it "opens a special listen only connection" do
    got = false
    ch = Channel(Nil).new
    conn = PG.connect_listen(DB_URL, "foo", "bar") do |n|
      got = true
      ch.send(nil)
    end

    begin
      got.should eq(false)

      PG_DB.exec("notify wrong, 'hello'")
      got.should eq(false)

      PG_DB.exec("notify foo, 'hello'")
      ch.receive
      got.should eq(true)
      got = false

      PG_DB.exec("notify bar, 'hello'")
      ch.receive
      got.should eq(true)
    ensure
      conn.close
    end
  end
end

describe PG, "#read_next_row_start" do
  it "handles reading a notice" do
    with_connection do |db|
      db.exec "SET client_min_messages TO notice"
      db.exec <<-SQL
        CREATE OR REPLACE FUNCTION foo() RETURNS integer AS $$
        BEGIN
          RAISE NOTICE 'foo';
          RAISE NOTICE 'bar';
          RETURN 42;
        END;
        $$ LANGUAGE plpgsql;
        SQL

      received_notices = [] of String
      db.on_notice do |notice|
        received_notices << notice.message
      end
      db.scalar("SELECT foo()").should eq 42
      received_notices.should eq ["foo", "bar"]

      db.exec("DROP FUNCTION foo()")
    end
  end
end

record PG::ConnectionSpec::TestUser, id : Int32, name : String do
  include DB::Serializable
end

describe PG, "#pipeline" do
  it "allows pipelined queries" do
    with_connection do |db|
      result_sets = db.pipeline do |pipe|
        pipe.query "SELECT 42"
        pipe.query "SELECT $1::int4 AS exchange, $2::int8 AS suffix", 867, 5309
        pipe.query "SELECT * FROM generate_series(1, 3)"
        pipe.query <<-SQL
          SELECT
            generate_series AS id,
            'Person #' || generate_series AS name
          FROM generate_series(1, 3)
        SQL
        50.times { |i| pipe.query "SELECT $1::int4 AS index", i }
      end
      result_sets.scalar(Int32).should eq 42
      result_sets.read_one({Int32, Int64}).should eq({867, 5309})
      result_sets.read_all(Int32).should eq [1, 2, 3]
      result_sets.read_all(PG::ConnectionSpec::TestUser).should eq [
        PG::ConnectionSpec::TestUser.new(1, "Person #1"),
        PG::ConnectionSpec::TestUser.new(2, "Person #2"),
        PG::ConnectionSpec::TestUser.new(3, "Person #3"),
      ]
      50.times { |i| result_sets.scalar(Int32).should eq i }
    end
  end
end
