module PG::Network
  # Represents PostgreSQL inet type - IP address with optional netmask
  struct Inet
    getter address : String
    getter netmask : UInt8

    def initialize(@address : String, @netmask : UInt8 = 32)
      if @address.includes?(':')
        @netmask = 128 if @netmask == 32
      end
    end

    def to_s(io)
      io << @address
      if (@address.includes?(':') && @netmask != 128) || (!@address.includes?(':') && @netmask != 32)
        io << '/' << @netmask
      end
    end

    def ipv4?
      @address.includes?('.')
    end

    def ipv6?
      @address.includes?(':')
    end
  end

  # Represents PostgreSQL cidr type - IP network
  struct Cidr
    getter address : String
    getter netmask : UInt8

    def initialize(@address : String, @netmask : UInt8)
    end

    def to_s(io)
      io << @address << '/' << @netmask
    end

    def ipv4?
      @address.includes?('.')
    end

    def ipv6?
      @address.includes?(':')
    end
  end

  # Represents PostgreSQL macaddr type - 6-byte MAC address
  struct MacAddr
    getter bytes : StaticArray(UInt8, 6)

    def initialize(@bytes : StaticArray(UInt8, 6))
    end

    def initialize(str : String)
      parts = str.split(/[:-]/)
      raise ArgumentError.new("Invalid MAC address format") unless parts.size == 6

      bytes = StaticArray(UInt8, 6).new do |i|
        parts[i].to_u8(16)
      end
      @bytes = bytes
    end

    def to_s(io)
      @bytes.each_with_index do |byte, i|
        io << ':' if i > 0
        byte.to_s(io, base: 16, precision: 2)
      end
    end
  end

  # Represents PostgreSQL macaddr8 type - 8-byte MAC address
  struct MacAddr8
    getter bytes : StaticArray(UInt8, 8)

    def initialize(@bytes : StaticArray(UInt8, 8))
    end

    def initialize(str : String)
      parts = str.split(/[:-]/)
      raise ArgumentError.new("Invalid MAC address format") unless parts.size == 8

      bytes = StaticArray(UInt8, 8).new do |i|
        parts[i].to_u8(16)
      end
      @bytes = bytes
    end

    def to_s(io)
      @bytes.each_with_index do |byte, i|
        io << ':' if i > 0
        byte.to_s(io, base: 16, precision: 2)
      end
    end
  end
end
