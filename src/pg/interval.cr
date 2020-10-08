module PG
  # A representation for INTERVAL data type.
  # https://www.postgresql.org/docs/current/datatype-datetime.html
  struct Interval
    getter microseconds, days, months

    def initialize(@microseconds : Int64 = 0, @days : Int32 = 0, @months : Int32 = 0)
    end

    # Create a `Time::Span` from this `PG::Interval`
    # If the interval covered in the interval exceeds the range of `Time::Span`
    #  then an exception is raised.
    def to_span(approx_months : Int? = nil)
      d = days

      unless months.zero?
        if approx_months
          d += approx_months * months
        else
          raise "Cannot represent a PG::Interval contaning months as Time::Span without approximating months to days"
        end
      end

      div = microseconds.divmod(1_000_000)
      seconds = div[0]
      nanoseconds = div[1] * 1_000

      Time::Span.new(days: d, seconds: seconds, nanoseconds: nanoseconds)
    end

    def to_month_span
      Time::MonthSpan.new(months)
    end

    def to_spans
      {
        to_time_span,
        to_time_month_span,
      }
    end
  end
end
