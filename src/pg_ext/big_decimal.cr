require "big"

module PG
  struct Numeric
    # Returns a BigDecimal representation of the numeric. This retains all
    # precision, but requires LibGMP installed.
    def to_big_d
      return BigDecimal.new(0, 0) if nan? || ndigits == 0

      ten_k = BigInt.new(10_000)
      num = digits.reduce(BigInt.new(0)) { |a, i| a*ten_k + BigInt.new(i) }
      scale = 4 * (ndigits - 1 - weight)
      quot = BigDecimal.new(num, scale)
      neg? ? -quot : quot
    end
  end

  class ResultSet
    def read(t : BigRational.class)
      read(PG::Numeric).to_big_d
    end

    def read(t : BigRational?.class)
      read(PG::Numeric?).try &.to_big_d
    end
  end
end
