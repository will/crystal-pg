module PG
  # Represents a PostgreSQL range type
  # Ranges can be bounded or unbounded, inclusive or exclusive
  struct Range(T)
    getter lower : T?
    getter upper : T?
    getter lower_inclusive : Bool
    getter upper_inclusive : Bool
    getter? empty : Bool

    def initialize(@lower : T?, @upper : T?, @lower_inclusive : Bool = true, @upper_inclusive : Bool = false, @empty : Bool = false)
    end

    def self.empty
      new(nil, nil, true, false, true)
    end

    def lower_bound
      if @lower_inclusive
        '['
      else
        '('
      end
    end

    def upper_bound
      if @upper_inclusive
        ']'
      else
        ')'
      end
    end

    def infinite_lower?
      @lower.nil? && !@empty
    end

    def infinite_upper?
      @upper.nil? && !@empty
    end

    def to_s(io)
      if @empty
        io << "empty"
      else
        io << lower_bound
        io << @lower if @lower
        io << ','
        io << @upper if @upper
        io << upper_bound
      end
    end

    def ==(other : Range)
      return true if @empty && other.empty?
      return false if @empty != other.empty?

      @lower == other.lower &&
        @upper == other.upper &&
        @lower_inclusive == other.lower_inclusive &&
        @upper_inclusive == other.upper_inclusive
    end
  end

  # Type aliases for specific PostgreSQL range types
  alias Int4Range = Range(Int32)
  alias Int8Range = Range(Int64)
  alias NumRange = Range(Numeric)
  alias TsRange = Range(Time)
  alias TsTzRange = Range(Time)
  alias DateRange = Range(Time)
end
