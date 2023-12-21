# IO object obtained through PG::Connection.exec_copy.
class PG::CopyResult < IO
  getter? closed : Bool

  def initialize(@connection : PQ::Connection, query : String)
      @connection.send_query_message query
      response = @connection.expect_frame PQ::Frame::CopyOutResponse | PQ::Frame::CopyInResponse

      @reading = response.is_a? PQ::Frame::CopyOutResponse
      @frame_size = 0
      @end = false
      @closed = false
  end

  private def read_final(done)
    return if @end
    @end = true

    unless done
      @connection.skip_bytes @frame_size if @frame_size > 0

      while @connection.read_next_copy_start
        size = @connection.read_i32 - 4
        @connection.skip_bytes size
      end
    end

    @connection.expect_frame PQ::Frame::CommandComplete
    @connection.expect_frame PQ::Frame::ReadyForQuery
  end

  # Returns the number of remaining bytes in the current row.
  # Returns 0 the are no more rows to be read.
  # This can be used to allocate the precise amount of memory to read a complete row.
  #
  # ```
  # size = io.remaining_row_size
  # if size != 0
  #   row = Bytes.new(size)
  #   io.read(row)
  #   # Process the row.
  # end
  # ```
  def remaining_row_size : Int32
    raise "Can't read from a write-only PG::CopyResult" unless @reading
    check_open

    return 0 if @end

    if @frame_size == 0
      if @connection.read_next_copy_start
        @frame_size = @connection.read_i32 - 4
      else
        read_final true
        return 0
      end
    end

    @frame_size
  end

  def read(slice : Bytes) : Int32
    return 0 if slice.empty?

    remaining = remaining_row_size
    return 0 if remaining == 0

    max_bytes = slice.size > remaining ? remaining : slice.size
    bytes = @connection.read_direct(slice[0..max_bytes - 1])
    @frame_size -= bytes
    bytes
  end

  def write(slice : Bytes) : Nil
    raise "Can't write to a read-only PG::CopyResult" if @reading
    @connection.send_copy_data_message slice
  end

  def close : Nil
    return if @closed
    if @reading
      read_final false
    else
      @connection.send_copy_done_message
      @connection.expect_frame PQ::Frame::CommandComplete
      @connection.expect_frame PQ::Frame::ReadyForQuery
    end
    @closed = true
  end
end
