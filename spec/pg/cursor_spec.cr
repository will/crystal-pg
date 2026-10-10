require "../spec_helper"

describe PG::Cursor do
  it "works with simple query" do
    with_connection do |conn|
      conn.exec("create table cursor_test (id serial, name text)")
      conn.exec("insert into cursor_test (name) values ('Alice'), ('Bob'), ('Charlie'), ('David'), ('Eve')")

      conn.transaction do
        cursor = conn.cursor("select * from cursor_test order by id")

        # Fetch first batch
        rows = [] of {Int32, String}
        cursor.fetch(2) do |rs|
          rows << {rs.read(Int32), rs.read(String)}
          while rs.move_next
            rows << {rs.read(Int32), rs.read(String)}
          end
        end

        rows.size.should eq(2)
        rows[0].should eq({1, "Alice"})
        rows[1].should eq({2, "Bob"})

        # Fetch next batch
        rows.clear
        cursor.fetch(2) do |rs|
          rows << {rs.read(Int32), rs.read(String)}
          while rs.move_next
            rows << {rs.read(Int32), rs.read(String)}
          end
        end

        rows.size.should eq(2)
        rows[0].should eq({3, "Charlie"})
        rows[1].should eq({4, "David"})

        cursor.close
      end
    ensure
      with_connection &.exec("drop table if exists cursor_test")
    end
  end

  it "works with block syntax" do
    with_connection do |conn|
      conn.exec("create table cursor_test2 (value int)")
      conn.exec("insert into cursor_test2 select generate_series(1, 10)")

      values = [] of Int32
      conn.transaction do
        conn.cursor("select value from cursor_test2 order by value") do |cursor|
          cursor.fetch_all do |rs|
            values << rs.read(Int32)
          end
        end
      end

      values.should eq((1..10).to_a)
    ensure
      with_connection &.exec("drop table if exists cursor_test2")
    end
  end

  it "supports cursor movement" do
    with_connection do |conn|
      conn.exec("create table cursor_test3 (id int)")
      conn.exec("insert into cursor_test3 select generate_series(1, 5)")

      conn.transaction do
        cursor = conn.cursor("select id from cursor_test3 order by id")

        # Move forward
        cursor.move(2)
        cursor.fetch(1) do |rs|
          rs.read(Int32).should eq(3)
        end

        # Move backward
        cursor.move(-1)
        cursor.fetch(1) do |rs|
          rs.read(Int32).should eq(3)
        end

        # Move to first
        cursor.move_first
        cursor.fetch(1) do |rs|
          rs.read(Int32).should eq(2) # After MOVE ABSOLUTE 1, FETCH gets the next row
        end

        # Move to last
        cursor.move_last
        cursor.fetch(1) do |rs|
          rs.read(Int32).should eq(5)
        end

        cursor.close
      end
    ensure
      with_connection &.exec("drop table if exists cursor_test3")
    end
  end

  it "works with parameterized queries" do
    with_connection do |conn|
      conn.exec("create table cursor_test4 (id int, category text)")
      conn.exec("insert into cursor_test4 values (1, 'A'), (2, 'B'), (3, 'A'), (4, 'B'), (5, 'A')")

      ids = [] of Int32
      conn.transaction do
        conn.cursor("select id from cursor_test4 where category = $1 order by id", "A") do |cursor|
          cursor.fetch_all do |rs|
            ids << rs.read(Int32)
          end
        end
      end

      ids.should eq([1, 3, 5])
    ensure
      with_connection &.exec("drop table if exists cursor_test4")
    end
  end

  it "automatically starts transaction if needed" do
    with_connection do |conn|
      conn.exec("create table cursor_test5 (id int)")
      conn.exec("insert into cursor_test5 values (42)")

      # Should start a transaction automatically
      cursor = conn.cursor("select id from cursor_test5")
      cursor.fetch(1) do |rs|
        rs.read(Int32).should eq(42)
      end
      cursor.close

      # Verify we're still in a transaction
      conn.in_transaction?.should be_true

      # End the transaction
      conn.exec("COMMIT")
    ensure
      with_connection &.exec("drop table if exists cursor_test5")
    end
  end

  it "raises on closed cursor operations" do
    with_connection do |conn|
      conn.transaction do
        cursor = conn.cursor("select 1")
        cursor.close

        expect_raises(DB::Error, "Cursor is closed") do
          cursor.fetch(1) { }
        end

        expect_raises(DB::Error, "Cursor is closed") do
          cursor.move(1)
        end
      end
    end
  end
end
