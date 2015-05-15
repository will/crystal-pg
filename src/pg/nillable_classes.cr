module PG
  module Nilable
    macro generate(list)
      {% for k in list %}
        alias Nilable{{k}} = Nil | {{k}}
      {% end %}
    end

    generate [String, Int32, Float64, Bool, Time]
  end

  include Nilable
end
