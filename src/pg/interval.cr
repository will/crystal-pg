module PG
  #
  # A representation for INTERVAL data type.
  # https://www.postgresql.org/docs/current/datatype-datetime.html
  #
  struct Interval
    getter microseconds, days, months

    def initialize(@microseconds : Int64 = 0, @days : Int32 = 0, @months : Int32 = 0)
    end

    #
    # Create a `Time::Span` from this `PG::Interval`
    # If the interval covered in the interval exceeds the range of `Time::Span`
    # then an exception is raised.
    #
    def to_span(ignore_overflow = false)
      if !ignore_overflow && months != 0
        message = "This PG::Interval has a month value and can not be covered in a Time::Span." \
                  "Call #to_span(true) to ignore overflowing parts."
        raise message
      end

      div = microseconds.divmod(1_000_000)
      seconds = div[0]
      nanoseconds = div[1] * 1_000

      Time::Span.new(days: days, seconds: seconds, nanoseconds: nanoseconds)
    end

    def to_month_span
      Time::MonthSpan.new(months)
    end

    def to_spans
      {
        to_time_span(false),
        to_time_month_span
      }
    end
  end
end
