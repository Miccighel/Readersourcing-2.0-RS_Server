require "base64"
require "json"

class PdfInspectionProtocol

  MAX_DEPTH = 24

  def self.encode(value, depth = 0)
    raise ArgumentError, "PDF metadata is too deeply nested" if depth > MAX_DEPTH

    case value
    when String then ["string", value.encoding.name, Base64.strict_encode64(value.b)]
    when Symbol then ["symbol", encode(value.to_s, depth + 1)]
    when Array then ["array", value.map { |entry| encode(entry, depth + 1) }]
    when Hash then ["hash", value.map { |key, entry| [encode(key, depth + 1), encode(entry, depth + 1)] }]
    when Integer, Float, TrueClass, FalseClass, NilClass then ["scalar", value]
    else raise ArgumentError, "Unsupported PDF metadata value"
    end
  end

  def self.decode(value, depth = 0)
    raise ArgumentError, "Invalid PDF metadata" unless value.is_a?(Array) && depth <= MAX_DEPTH

    case value.first
    when "string"
      raise ArgumentError unless value.size == 3 && value[1].is_a?(String) && value[2].is_a?(String)
      Base64.strict_decode64(value[2]).force_encoding(Encoding.find(value[1]))
    when "symbol"
      decoded = decode(value.fetch(1), depth + 1)
      raise ArgumentError unless value.size == 2 && decoded.is_a?(String)
      decoded.to_sym
    when "array"
      raise ArgumentError unless value.size == 2 && value[1].is_a?(Array)
      value[1].map { |entry| decode(entry, depth + 1) }
    when "hash"
      raise ArgumentError unless value.size == 2 && value[1].is_a?(Array)
      value[1].to_h do |pair|
        raise ArgumentError unless pair.is_a?(Array) && pair.size == 2
        [decode(pair[0], depth + 1), decode(pair[1], depth + 1)]
      end
    when "scalar"
      scalar = value[1]
      raise ArgumentError unless value.size == 2 && [Integer, Float, TrueClass, FalseClass, NilClass].any? { |type| scalar.is_a?(type) }
      scalar
    else raise ArgumentError, "Invalid PDF metadata type"
    end
  end

end
