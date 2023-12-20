class PG::CopyOut < IO
  getter? closed : Bool

  def initialize(@connection : PQ::Connection, query : String)
      @connection.send_query_message query
      @connection.expect_frame PQ::Frame::CopyOutResponse

      @frame_size = 0 # Remaining bytes in the current frame
      @end = false
      @closed = false
  end

  def read(slice : Bytes) : Int32
    check_open

    return 0 if slice.empty?
    return 0 if @end

    if @frame_size == 0
      if @connection.read_next_copy_start
        @frame_size = @connection.read_i32 - 4
      else
        @end = true
        return 0
      end
    end

    max_bytes = slice.size > @frame_size ? @frame_size : slice.size
    bytes = @connection.read_direct(slice[0..max_bytes - 1])
    @frame_size -= bytes
    bytes
  end

  def write(slice : Bytes) : NoReturn
    raise "Can't write to PG::CopyOut"
  end

  def close : Nil
    return if @closed
    @closed = true

    unless @end
      while @connection.read_next_copy_start
        size = @connection.read_i32 - 4
        @connection.skip_bytes size
      end
    end

    @connection.expect_frame PQ::Frame::CommandComplete
    @connection.expect_frame PQ::Frame::ReadyForQuery
  end
end
