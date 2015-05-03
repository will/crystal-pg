module PG
  class Result

    struct Field
      property name
      property oid
      def initialize(@name, @oid) end

      def self.new_from_res(res, col)
        new(
          String.new(LibPQ.fname(res, col)),
          LibPQ.ftype(res, col)
        )
      end

      def decoder
        PG::Decoder.from_oid(oid)
      end
    end

    getter fields
    getter rows
    def initialize(@res)
      @fields = gather_fields
      @rows   = gather_rows
      clear_res
    end

    def to_hash
      field_names = fields.map(&.name)

      if field_names.uniq.size != field_names.size
        raise PG::RuntimeError.new("Duplicate field names in result set")
      end

      rows.map do |row|
        Hash.zip(field_names, row)
      end
    end

    private getter res

    private def nfields
      @nfields ||= LibPQ.nfields(res)
    end

    private def ntuples
      @ntuples ||= LibPQ.ntuples(res)
    end

    private def decoders
      @decoders ||= fields.map(&.decoder)
    end

    private def gather_fields
      fds = Array(Field).new(nfields)
      nfields.times do |i|
        fds << Field.new_from_res(res, i)
      end
      fds
    end

    private def gather_rows
      rws = Array( Array(PGValue) ).new(ntuples)
      ntuples.times do |i|
        rws << Array(PGValue).new(nfields)
        nfields.times do |j|
          val = decode_value(res, i, j)
          rws[i] << val
        end
      end
      rws
    end

    private def decode_value(res, row, col)
      val_ptr = LibPQ.getvalue(res, row, col)
      if val_ptr.value == 0 && LibPQ.getisnull(res, row, col)
        nil
      else
        decoders[col].decode(val_ptr)
      end
    end

    def self.clear_res(res)
      LibPQ.clear(res)
    end

    private def clear_res
      self.class.clear_res(res)
      @res = nil
    end

  end
end

