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

    getter res
    def initialize(@res) end

    def nfields
      @nfields ||= LibPQ.nfields(res)
    end

    def ntuples
      @ntuples ||= LibPQ.ntuples(res)
    end

    def decoders
      @decoders ||= fields.map(&.decoder)
    end

    def fields
      fds = Array(Field).new(nfields)
      i = 0
      while i < nfields
        fds << Field.new_from_res(res, i)
        i += 1
      end
      fds
    end

    def rows
      rws = Array( Array(PGValue) ).new(ntuples)
      i = 0
      while i < ntuples
        rws << Array(PGValue).new(nfields)
        j = 0
        while j < nfields
          val = decode_value(res, i, j)
          rws[i] << val
          j += 1
        end
        i += 1
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

  end
end

