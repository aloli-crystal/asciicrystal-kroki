require "compress/deflate"
require "base64"

module AsciicrystalKroki
  # Encodes diagram source text for use in Kroki GET URLs.
  #
  # The encoding process is:
  # 1. Deflate-compress the diagram source text
  # 2. Base64url-encode the compressed bytes (no padding)
  #
  # This produces a URL-safe string that can be used in:
  #   {server}/{diagram_type}/{format}/{encoded}
  module Encoder
    # Encode diagram source text for a Kroki GET URL.
    def self.encode(text : String) : String
      # Deflate-compress the text
      compressed = IO::Memory.new
      Compress::Deflate::Writer.open(compressed) do |deflate|
        deflate.print(text)
      end

      # Base64url-encode without padding
      Base64.urlsafe_encode(compressed.to_slice, padding: false)
    end

    # Decode an encoded Kroki string back to the original text.
    # Useful for testing.
    def self.decode(encoded : String) : String
      # Restore padding if needed
      padded = encoded
      case encoded.size % 4
      when 2 then padded = encoded + "=="
      when 3 then padded = encoded + "="
      end

      compressed = Base64.decode(padded.tr("-_", "+/"))
      io = IO::Memory.new(compressed)
      Compress::Deflate::Reader.open(io) do |deflate|
        deflate.gets_to_end
      end
    end

    # Build a full Kroki GET URL for the given diagram.
    def self.build_url(server_url : String, diagram_type : String, format : String, source : String) : String
      encoded = encode(source)
      "#{server_url}/#{diagram_type}/#{format}/#{encoded}"
    end
  end
end
