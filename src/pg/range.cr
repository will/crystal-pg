module PG
  # Represents a PostgreSQL range value without losing bound inclusivity.
  struct Range(T)
    getter begin : T?
    getter end : T?
    getter lower_inclusive : Bool
    getter upper_inclusive : Bool

    def self.empty
      new(empty: true)
    end

    def initialize(@begin : T? = nil, @end : T? = nil, @lower_inclusive : Bool = true, @upper_inclusive : Bool = false, @empty : Bool = false)
    end

    def empty?
      @empty
    end

    def excludes_begin?
      !@lower_inclusive
    end

    def excludes_end?
      !@upper_inclusive
    end

    def to_crystal_range
      ::Range.new(@begin, @end, exclusive: excludes_end?)
    end

    def ==(other : self)
      empty? == other.empty? &&
        @begin == other.begin &&
        self.end == other.end &&
        lower_inclusive == other.lower_inclusive &&
        upper_inclusive == other.upper_inclusive
    end

    def ==(other : ::Range)
      if empty?
        other.begin == other.end && other.excludes_end?
      else
        to_crystal_range == other
      end
    end

    def to_s(io : IO) : Nil
      if empty?
        io << "empty"
      else
        io << (lower_inclusive ? '[' : '(')
        io << @begin unless @begin.nil?
        io << ','
        io << @end unless @end.nil?
        io << (upper_inclusive ? ']' : ')')
      end
    end
  end
end
