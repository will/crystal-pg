require "../spec_helper"

class TestMessageHandler
  include PG::Replication::Handler

  getter relations : Hash(Int32, PG::Replication::Relation) = Hash(Int32, PG::Replication::Relation).new
  getter types = Hash(Int32, PG::Replication::Type).new
  getter truncations = [] of PG::Replication::Truncate
  getter transaction : Transaction?
  getter data = Hash(Int32, Hash(Bytes, PG::Replication::WALMessage::TupleData)).new { |h, k|
    h[k] = {} of Bytes => PG::Replication::WALMessage::TupleData
  }

  def received(msg : PG::Replication::Begin)
    if transaction
      raise "We are already running a transaction"
    end

    @transaction = Transaction.new(
      id: msg.transaction_id,
      final_lsn: msg.final_lsn,
      timestamp: msg.timestamp,
    )
  end

  def received(msg : PG::Replication::Message)
  end

  def received(msg : PG::Replication::Commit)
    transaction!.events.each do |event|
      if relation = relations[event.oid]
        # There can be multiple parts of the primary key
        case event.type
        in .insert?, .update?
          if (key = relation.columns.map_with_index { |column, index| index if column.flags.key? }.compact).any?
            data[event.oid][Slice.join(key.map { |key_part_index| make_key(event.tuple_data[key_part_index]) })] = event.tuple_data
          else
            # What do?
          end
        in .delete?
          if (key = relation.columns.map_with_index { |column, index| index if column.flags.key? }.compact).any?
            data[event.oid].delete Slice.join(key.map { |key_part_index| make_key(event.tuple_data[key_part_index]) })
          else
            # What do?
          end
        end
      end
    end
    @transaction = nil
  end

  def received(msg : PG::Replication::Origin)
  end

  def received(msg : PG::Replication::Relation)
    relations[msg.oid] = msg
  end

  def received(type : PG::Replication::Type)
    types[type.oid] = type
  end

  def received(msg : PG::Replication::Insert)
    transaction!.insert oid: msg.oid, tuple_data: msg.tuple_data
  end

  def received(msg : PG::Replication::Update)
    transaction!.update oid: msg.oid, tuple_data: msg.new_tuple_data,
      old_tuple_data: msg.old_tuple_data,
      key_tuple_data: msg.key_tuple_data
  end

  def received(msg : PG::Replication::Delete)
    transaction!.delete oid: msg.oid, tuple_data: {msg.key_tuple_data, msg.old_tuple_data}.first.not_nil!
  end

  def received(msg : PG::Replication::Truncate)
    truncations << msg
  end

  # TODO: Implement the methods below in order to test higher `proto_version`s

  # Requires proto_version >= 2
  # def received(msg : PG::Replication::StreamStart)
  # end

  # def received(msg : PG::Replication::StreamStop)
  # end

  # def received(msg : PG::Replication::StreamCommit)
  # end

  # def received(msg : PG::Replication::StreamAbort)
  # end

  # Requires proto_version >= 3
  # def received(msg : PG::Replication::BeginPrepare)
  # end

  # def received(msg : PG::Replication::Prepare)
  # end

  # def received(msg : PG::Replication::CommitPrepared)
  # end

  # def received(msg : PG::Replication::RollbackPrepared)
  # end

  # def received(msg : PG::Replication::StreamPrepare)
  # end

  private def transaction!
    transaction.not_nil!
  end

  private def make_key(value : String | Bytes) : Bytes
    value.to_slice
  end

  private def make_key(value : PG::Replication::WALMessage::UnchangedTOASTValue) : Bytes
    raise ArgumentError.new("Using a TOASTed value in a primary key is unsupported")
  end

  private def make_key(value : Nil) : Bytes
    Bytes.empty
  end

  class Transaction
    getter id : Int32
    getter final_lsn : Int64
    getter timestamp : Time
    getter events : Array(Event)

    alias TupleData = PG::Replication::WALMessage::TupleData

    def initialize(@id, @final_lsn, @timestamp, @events = [] of Event)
    end

    def insert(oid : Int32, tuple_data : PG::Replication::WALMessage::TupleData)
      events << Event.new(oid, tuple_data, :insert)
    end

    def update(oid : Int32, tuple_data : TupleData, old_tuple_data : TupleData?, key_tuple_data : TupleData?)
      events << Event.new(oid, tuple_data, :update, old_tuple_data: old_tuple_data, key_tuple_data: key_tuple_data)
    end

    def delete(oid : Int32, tuple_data : PG::Replication::WALMessage::TupleData)
      events << Event.new(oid, tuple_data, :delete)
    end

    record Event,
      oid : Int32,
      tuple_data : TupleData,
      type : Type,
      old_tuple_data : TupleData? = nil,
      key_tuple_data : TupleData? = nil do
      enum Type
        Insert
        Update
        Delete
      end
    end
  end
end

if PG_DB.query_one("SHOW wal_level", as: String) == "logical"
  describe PG::Replication do
    it_consumes_wal "new relations" do |handler, context|
      PG_DB.exec "CREATE TABLE #{context.table_name} (id UUID PRIMARY KEY, string TEXT)"
      # Apparently the Relation message isn't sent until after data is inserted
      # into the table. Without this insert, the `wait_for` call times out.
      PG_DB.exec "INSERT INTO #{context.table_name} (id, string) VALUES ($1, $2)", UUID.v7, "yep"

      wait_for { handler.relations.any? }
      oid, relation = handler.relations.first

      relation.namespace.should eq "public"
      relation.name.should eq context.table_name
      # The `id` column must be indicated as part of the relation's primary key
      relation.columns
        .find! { |column| column.name == "id" }
        .flags.key?.should eq true
    end

    it_consumes_wal "inserts" do |handler, context|
      id = UUID.v7
      string = "asdf"
      PG_DB.exec "CREATE TABLE #{context.table_name} (id UUID PRIMARY KEY, string TEXT)"
      PG_DB.exec "INSERT INTO #{context.table_name} (id, string) VALUES ($1, $2)", id, string

      wait_for { handler.data.any?(&.last.any?) }

      _, records = handler.data.first
      pk, tuple = records.first
      pk.should eq id.bytes.to_slice
      tuple[1].should eq string.to_slice
    end

    it_consumes_wal "updates" do |handler, context|
      id = UUID.v7
      string = "omg"
      PG_DB.exec "CREATE TABLE #{context.table_name} (id UUID PRIMARY KEY, string TEXT)"
      PG_DB.exec "INSERT INTO #{context.table_name} (id, string) VALUES ($1, $2)", id, string
      PG_DB.exec "UPDATE #{context.table_name} SET string = 'lol' WHERE id = $1", id

      # Wait for at least the insert to propagate
      wait_for { handler.data.any?(&.last.any?) }
      # Give the update just a little longer to come in
      wait_for "record to be updated" do
        _, records = handler.data.first
        _, tuple = records.first
        tuple[1] == "lol".to_slice
      end
    end

    it_consumes_wal "deletes" do |handler, context|
      id = UUID.v7
      string = "omg"
      PG_DB.exec "CREATE TABLE #{context.table_name} (id UUID PRIMARY KEY, string TEXT)"
      PG_DB.exec "INSERT INTO #{context.table_name} (id, string) VALUES ($1, $2)", id, string
      PG_DB.exec "DELETE FROM #{context.table_name} WHERE id = $1", id

      # Wait for at least the insert to propagate
      wait_for { handler.data.any?(&.last.any?) }
      # Give the delete just a little longer to come in
      wait_for "data to be deleted" { handler.data.first.last.none? }
    end

    it_consumes_wal "new types" do |handler, context|
      PG_DB.exec "CREATE TYPE #{context.type_name} AS ENUM ('one', 'two', 'three')"
      # The type isn't sent until there's a table that uses it
      PG_DB.exec "CREATE TABLE #{context.table_name} (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), thing #{context.type_name})"
      # ... and the table isn't sent until there's a record in it
      PG_DB.exec "INSERT INTO #{context.table_name} (thing) VALUES ('three')"

      # Wait for the insert to propagate
      wait_for { handler.types.any? }

      handler.types.first.last.data_type.should eq context.type_name
    end

    it_consumes_wal "schema changes" do |handler, context|
      PG_DB.exec "CREATE TABLE #{context.table_name} (id UUID PRIMARY KEY DEFAULT gen_random_uuid())"
      PG_DB.exec "INSERT INTO #{context.table_name} (id) VALUES ($1)", UUID.v7
      wait_for { handler.relations.any? }
      # Make sure we get that the table has 1 column before proceeding
      wait_for { handler.relations.first.last.columns.size == 1 }

      PG_DB.exec "ALTER TABLE #{context.table_name} ADD COLUMN string TEXT"
      PG_DB.exec "INSERT INTO #{context.table_name} (id, string) VALUES ($1, $2)", UUID.v7, "my string"

      # Now the table has 2 columns
      wait_for { handler.relations.first.last.columns.size == 2 }
    end

    it_consumes_wal "truncations" do |handler, context|
      PG_DB.exec "CREATE TABLE #{context.table_name} (id UUID PRIMARY KEY DEFAULT gen_random_uuid())"
      PG_DB.exec "INSERT INTO #{context.table_name} (id) VALUES ($1)", UUID.v7
      wait_for { handler.relations.any? }

      PG_DB.exec "TRUNCATE #{context.table_name}"

      wait_for { handler.truncations.any? }
    end
  end
else
  Log.warn { "Skipping #{__FILE__}, set wal_level=logical in postgresql.conf to enable" }
end

private def it_consumes_wal(name : String, **options, &block : TestMessageHandler, Context ->)
  it "consumes #{name} from the WAL", **options do
    context = Context.new
    handler = TestMessageHandler.new
    PG_DB.exec "CREATE PUBLICATION #{context.publication_name} FOR ALL TABLES"
    PG_DB.exec "SELECT pg_create_logical_replication_slot($1, 'pgoutput')", context.slot_name
    subscriber = PG.connect_replication DB_URL,
      handler: handler,
      publication_name: context.publication_name,
      slot_name: context.slot_name

    begin
      block.call handler, context
    ensure
      subscriber.try &.close
      PG_DB.exec "SELECT pg_drop_replication_slot(slot_name) FROM pg_replication_slots WHERE slot_name LIKE 'test_slot_%'"
      PG_DB.query_each "SELECT pubname::text FROM pg_publication_tables WHERE schemaname = 'public' and pubname::text LIKE 'test_publication_%' GROUP BY 1" do |rs|
        PG_DB.exec "DROP PUBLICATION IF EXISTS #{rs.read(String)}"
      end
      PG_DB.query_each "SELECT tablename::text FROM pg_tables WHERE schemaname = 'public' and tablename LIKE 'test_table_%'" do |rs|
        PG_DB.exec "DROP TABLE IF EXISTS #{rs.read(String)}"
      end
      PG_DB.query_each "SELECT typname::text FROM pg_type WHERE typname LIKE 'test_type_%'" do |rs|
        PG_DB.exec "DROP TYPE IF EXISTS #{rs.read(String)}"
      end
    end
  end
end

private record Context,
  table_name : String = "test_table_#{Random::Secure.hex}",
  publication_name : String = "test_publication_#{Random::Secure.hex}",
  slot_name : String = "test_slot_#{Random::Secure.hex}",
  type_name : String = "test_type_#{Random::Secure.hex}"

private def wait_for(condition = "the block to return truthy", timeout : Time::Span = 2.seconds, &)
  start = Time.monotonic
  until yield
    if Time.monotonic - start > 2.seconds
      raise "Timed out waiting for #{condition}"
    end
    sleep 1.millisecond
  end
end
