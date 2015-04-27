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
    end

    getter res
    def initialize(@res) end

    def nfields
      @nfields ||= LibPQ.nfields(res)
    end

    def ntuples
      @ntuples ||= LibPQ.ntuples(res)
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
      rws = Array( Array(String) ).new(ntuples)
      i = 0
      while i < ntuples
        rws << Array(String).new(nfields)
        j = 0
        while j < nfields
          val = String.new(LibPQ.getvalue(res, i, j))
          rws[i] << val
          j += 1
        end
        i += 1
      end
      rws
    end

  end
end

