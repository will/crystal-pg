class PG::ResultSet < ::DB::ResultSet
  def initialize(statement, @fields : Array(PQ::Field)?)
    super(statement)
    @column_index = -1 # The current column
    @end = false       # Did we read all the rows?
  end

  protected def conn
    statement.as(Statement).conn
  end

  def move_next
    return false if @end

    fields = @fields

    # `move_next` might be called before consuming all rows,
    # in that case we need to skip columns
    if fields && @column_index > -1 && @column_index < fields.size
      while @column_index < fields.size
        skip
      end
    end

    unless fields
      @end = true
      conn.expect_frame PQ::Frame::CommandComplete | PQ::Frame::EmptyQueryResponse
      conn.expect_frame PQ::Frame::ReadyForQuery
      return false
    end

    if conn.read_next_row_start
      # We ignore these (redundant information)
      conn.read_i32 # size
      conn.read_i16 # ncols
      @column_index = 0
      true
    else
      conn.expect_frame PQ::Frame::ReadyForQuery
      @end = true
      false
    end
  end

  def column_count : Int32
    @fields.try(&.size) || 0
  end

  def column_name(index : Int32) : String
    field(index).name
  end

  def column_type(index : Int32)
    decoder(index).type
  end

  def read
    col_bytesize = conn.read_i32
    if col_bytesize == -1
      @column_index += 1
      return nil
    end

    value = decoder.decode(conn.soc, col_bytesize)
    @column_index += 1
    value
  end

  private def field(index = @column_index)
    @fields.not_nil![index]
  end

  private def decoder(index = @column_index)
    Decoders.from_oid(field(index).type_oid)
  end

  private def skip
    col_size = conn.read_i32
    conn.skip_bytes(col_size) if col_size != 1
    @column_index += 1
  end

  protected def do_close
    super

    # Nothing to do if all the rows were consumed
    return if @end

    # Check if we didn't advance to the first row
    if @column_index == -1
      return unless move_next
    end

    fields = @fields

    loop do
      # Skip remaining columns
      while fields && @column_index < fields.size
        skip
      end

      break unless move_next
    end
  end
end
