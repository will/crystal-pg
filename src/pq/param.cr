module PQ
  # :nodoc:
  record Param, slice : Slice(UInt8), size : Int32, format : Int16 do
    delegate to_unsafe, slice

    #  Internal wrapper to represent an encoded parameter

    # The only special case is nil->null and slice.
    # If more types need special cases, there should be an encoder
    def self.encode(val)
      if val.nil?
        binary Pointer(UInt8).null.to_slice(0), -1
      elsif val.is_a? Slice
        binary val, val.size
      else
        text val.to_s.to_slice
      end
    end

    def self.binary(slice, size)
      new slice, size, 1_i16
    end

    def self.text(slice)
      new slice, slice.size, 0_i16
    end
  end
end
