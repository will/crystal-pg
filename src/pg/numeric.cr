module PG
  # The Postgres numeric type has arbitrary precision, and can be NaN, "not a
  # number".
  #
  # The default version of `Numeric` in this driver only has `#to_f` which
  # provides approximate conversion. To get true arbitrary precision, there is
  # an optional extension `pg_ext/big_rational`, however LibGMP must be
  # installed.
  struct Numeric
    # :nodoc:
    enum Sign
      Pos =  0x0000
      Neg =  0x4000
      Nan = -0x4000
    end

    # size of digits array
    getter ndigits : Int16

    # location of decimal point in digits array
    # can be negative for small numbers such as 0.0000001
    getter weight : Int16

    # positive, negative, or nan
    getter sign : Sign

    # number of decimal point digits shown
    # 1.10 is and 1.100 would only differ here
    getter dscale : Int16

    # array of numbers from 0-10,000 representing the numeric
    # (not an array of individual digits!)
    getter digits : Array(Int16)

    def initialize(@ndigits, @weight, sign, @dscale, @digits)
      @sign = Sign.from_value(sign)
    end

    # Returns `true` if the numeric is not a number.
    def nan?
      sign == Sign::Nan
    end

    # Returns `true` if the numeric is negative.
    def neg?
      sign == Sign::Neg
    end

    # The approximate representation of the numeric as a 64-bit float.
    #
    # Very small and very large values may be inaccurate and precision will be
    # lost.
    # NaN returns `0.0`.
    def to_f : Float64
      to_f64
    end

    # ditto
    def to_f64 : Float64
      num = digits.reduce(0_u64) { |a, i| a*10_000_u64 + i.to_u64 }
      den = 10_000_f64**(ndigits - 1 - weight)
      quot = num.to_f64 / den.to_f64
      neg? ? -quot : quot
    end

    def to_s(io : IO)
      if ndigits == 0
        if nan?
          io << "NaN"
        else
          io << '0'
          if dscale > 0
            io << '.'
            dscale.times { io << '0' }
          end
        end

        return
      end

      io << '-' if neg?

      if weight >= 0
        (0..weight).each { |idx| io << digits[idx].to_s }
      end

      return if dscale <= 0

      io << '0' if weight < 0
      io << '.'

      extra = ndigits == 1 ? 1 : (dscale % 4)
      if weight < 0
        (dscale + weight + extra).times { io << '0' }
        start = 0
      else
        start = weight + 1
      end
      (start...ndigits - 1).each { |idx| io << digits[idx].to_s }
      io << digits[ndigits - 1].to_s[0..extra - 1]
    end
  end
end
