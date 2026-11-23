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

    def initialize(
      begin lower : T? = nil,
      end upper : T? = nil,
      @lower_inclusive : Bool = !lower.nil?,
      @upper_inclusive : Bool = false,
      @empty : Bool = false,
    )
      if lower_inclusive && lower.nil?
        raise ArgumentError.new("A range with an infinite lower bound cannot include the lower end")
      end

      if upper_inclusive && upper.nil?
        raise ArgumentError.new("A range with an infinite upper bound cannot include the upper end")
      end

      @begin = lower
      @end = upper
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
      if excludes_begin? && !@begin.nil?
        raise Error.new("Cannot convert #{inspect} to a ::Range type because it excludes the lower bound")
      end

      ::Range.new(@begin, @end, exclusive: excludes_end?)
    end

    def ==(other : Range)
      empty? == other.empty? &&
        self.begin == other.begin &&
        self.end == other.end &&
        lower_inclusive == other.lower_inclusive &&
        upper_inclusive == other.upper_inclusive
    end

    def ==(other : ::Range)
      if empty?
        other.begin == other.end && other.excludes_end?
      else
        self.begin == other.begin &&
          self.end == other.end &&
          lower_inclusive == !other.begin.nil? &&
          upper_inclusive == (!other.excludes_end? && !other.end.nil?)
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
