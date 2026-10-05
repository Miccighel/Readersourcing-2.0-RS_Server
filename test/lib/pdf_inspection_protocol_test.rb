require "test_helper"
require_relative "../../lib/pdf_inspection_protocol"

class PdfInspectionProtocolTest < ActiveSupport::TestCase

  test "preserves metadata bytes, encodings, names, and nested values through JSON" do
    metadata = {Title: +"Readersourcing\x84", BaseUrl: "https://example.test/rate", Custom: [:name, 3, 0.5, nil, false, {"nested" => "value".b}]}
    restored = PdfInspectionProtocol.decode(JSON.parse(JSON.generate(PdfInspectionProtocol.encode(metadata))))

    assert_equal metadata, restored
    assert_equal metadata[:Title].bytes, restored[:Title].bytes
    assert_equal metadata[:Title].encoding, restored[:Title].encoding
    assert_equal Encoding::ASCII_8BIT, restored[:Custom].last.fetch("nested").encoding
  end

  test "does not deserialize arbitrary objects or recursive structures" do
    assert_raises(ArgumentError) { PdfInspectionProtocol.encode(Object.new) }
    assert_raises(ArgumentError) { PdfInspectionProtocol.decode(["object", "Kernel"]) }
    recursive = []
    recursive << recursive
    assert_raises(ArgumentError) { PdfInspectionProtocol.encode(recursive) }
  end

end
