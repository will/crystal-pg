require "../../pg"

module PG
  module Extension
    # This extension adds support for decoding the Postgres `citext` type.
    class CIText
      include Extension

      def load(connection)
        oid = connection.query_one "SELECT oid FROM pg_type WHERE typname = 'citext'", as: UInt32
        connection.register_decoder Decoder.new([oid.to_i])
      end

      struct Decoder
        include Decoders::Decoder

        getter oids : Array(Int32)

        def initialize(@oids : Array(Int32))
        end

        def decode(io, bytesize, oid)
          PG::CIText.new(Decoders::StringDecoder.new.decode(io, bytesize, oid))
        end

        def type
          PG::CIText
        end
      end
    end

    Connection.register_extension CIText.new
  end

  struct CIText
    def initialize(text : String)
      @text = text
    end

    def hash(hasher)
      @text.hash(hasher)
    end

    def ==(other : self)
      self == other.@text
    end

    def ==(other : String)
      @text.compare(other, case_insensitive: true)
    end

    def to_s(io)
      @text.to_s io
    end
  end
end

class String
  def ==(other : PG::CIText)
    other == self
  end
end
