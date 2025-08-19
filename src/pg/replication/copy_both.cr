require "./frame"

module PG::Replication
  struct CopyBoth < Frame
    getter format : Format
    getter column_formats : Array(Int16)

    def initialize(io : IO)
      size = io.read_bytes(Int32, IO::ByteFormat::NetworkEndian)
      sized = IO::Sized.new(io, size - 4)
      @format = Format.new(sized.read_bytes(Int8, IO::ByteFormat::NetworkEndian))
      column_count = sized.read_bytes(Int16, IO::ByteFormat::NetworkEndian)
      @column_formats = Array.new(column_count) do
        sized.read_bytes(Int16, IO::ByteFormat::NetworkEndian)
      end
      sized.close
    end

    enum Format : Int8
      Text   = 0
      Binary = 1
    end
  end
end
