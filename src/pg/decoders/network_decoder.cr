require "../network"

module PG
  module Decoders
    # Helper method to format IPv6 addresses with proper compression
    def self.format_ipv6(words : StaticArray(UInt16, 8)) : String
      # Convert to array of hex strings
      hex_parts = words.to_a.map { |w| w.to_s(16) }

      # Find longest sequence of zeros for compression
      max_start = -1
      max_len = 0
      current_start = -1

      8.times do |i|
        if words[i] == 0
          current_start = i if current_start == -1
        else
          if current_start != -1
            len = i - current_start
            if len > max_len && len > 1
              max_start = current_start
              max_len = len
            end
            current_start = -1
          end
        end
      end

      # Check if zeros extend to the end
      if current_start != -1
        len = 8 - current_start
        if len > max_len && len > 1
          max_start = current_start
          max_len = len
        end
      end

      # Build the compressed string
      if max_start >= 0
        parts = [] of String

        # Add parts before compression
        if max_start > 0
          parts.concat(hex_parts[0...max_start])
        end

        # Add empty string for ::
        parts << ""

        # Add parts after compression
        end_pos = max_start + max_len
        if end_pos < 8
          parts << "" if max_start == 0 # Leading ::
          parts.concat(hex_parts[end_pos...8])
        else
          parts << "" # Trailing ::
        end

        parts.join(":")
      else
        hex_parts.join(":")
      end
    end

    struct InetDecoder
      include Decoder

      def_oids [
        869, # inet
      ]

      def decode(io, bytesize, oid)
        family = io.read_byte.not_nil!
        netmask = io.read_byte.not_nil!
        is_cidr = io.read_byte.not_nil! == 1
        nb = io.read_byte.not_nil!

        if family == 2 # AF_INET (IPv4)
          bytes = uninitialized UInt8[4]
          io.read_fully(bytes.to_slice[0, nb])
          address = bytes.map(&.to_s).join('.')
        elsif family == 3 # AF_INET6 (IPv6)
          words = uninitialized UInt16[8]
          (nb // 2).times do |i|
            words[i] = read_u16(io)
          end
          ((nb // 2)...8).each do |i|
            words[i] = 0_u16
          end
          address = Decoders.format_ipv6(words)
        else
          raise "Unknown inet family: #{family}"
        end

        PG::Network::Inet.new(address, netmask)
      end

      def type
        PG::Network::Inet
      end

      private def read_u16(io)
        io.read_bytes(UInt16, IO::ByteFormat::NetworkEndian)
      end
    end

    struct CidrDecoder
      include Decoder

      def_oids [
        650, # cidr
      ]

      def decode(io, bytesize, oid)
        family = io.read_byte.not_nil!
        netmask = io.read_byte.not_nil!
        is_cidr = io.read_byte.not_nil! == 1
        nb = io.read_byte.not_nil!

        if family == 2 # AF_INET (IPv4)
          bytes = uninitialized UInt8[4]
          io.read_fully(bytes.to_slice[0, nb])
          # For CIDR, normalize the address based on netmask
          mask_bytes = (netmask / 8).to_i
          mask_bits = netmask % 8

          if mask_bytes < 4
            (mask_bytes...4).each { |i| bytes[i] = 0 }
          end
          if mask_bits > 0 && mask_bytes < 4
            bytes[mask_bytes] = (bytes[mask_bytes] & (0xFF_u8 << (8 - mask_bits)))
          end

          address = bytes.map(&.to_s).join('.')
        elsif family == 3 # AF_INET6 (IPv6)
          words = uninitialized UInt16[8]
          (nb // 2).times do |i|
            words[i] = read_u16(io)
          end
          ((nb // 2)...8).each do |i|
            words[i] = 0_u16
          end
          address = Decoders.format_ipv6(words)
        else
          raise "Unknown cidr family: #{family}"
        end

        PG::Network::Cidr.new(address, netmask)
      end

      def type
        PG::Network::Cidr
      end

      private def read_u16(io)
        io.read_bytes(UInt16, IO::ByteFormat::NetworkEndian)
      end
    end

    struct MacAddrDecoder
      include Decoder

      def_oids [
        829, # macaddr
      ]

      def decode(io, bytesize, oid)
        bytes = uninitialized UInt8[6]
        io.read_fully(bytes.to_slice)
        PG::Network::MacAddr.new(bytes)
      end

      def type
        PG::Network::MacAddr
      end
    end

    struct MacAddr8Decoder
      include Decoder

      def_oids [
        774, # macaddr8
      ]

      def decode(io, bytesize, oid)
        bytes = uninitialized UInt8[8]
        io.read_fully(bytes.to_slice)
        PG::Network::MacAddr8.new(bytes)
      end

      def type
        PG::Network::MacAddr8
      end
    end

    # Register the network decoders
    register_decoder InetDecoder.new
    register_decoder CidrDecoder.new
    register_decoder MacAddrDecoder.new
    register_decoder MacAddr8Decoder.new
  end
end
