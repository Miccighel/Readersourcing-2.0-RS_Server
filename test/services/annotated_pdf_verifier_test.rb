require "test_helper"

class AnnotatedPdfVerifierTest < ActiveSupport::TestCase

  test "accepts an annotated publication with the expected page and URL" do
    inspector = Struct.new(:document) do
      def call(*)
        document
      end
    end.new(PdfInspector::Document.new(metadata: {BaseUrl: "https://example.test/rate"}, page_count: 8))

    assert AnnotatedPdfVerifier.new(inspector: inspector).call(
      "Reader-Link.pdf",
      source_page_count: 7,
      expected_url: "https://example.test/rate"
    )
  end

  test "rejects an unexpected page count or rating URL" do
    inspector = Struct.new(:document) do
      def call(*)
        document
      end
    end.new(PdfInspector::Document.new(metadata: {BaseUrl: "https://wrong.test/rate"}, page_count: 7))

    verifier = AnnotatedPdfVerifier.new(inspector: inspector)
    assert_raises(AnnotatedPdfVerifier::VerificationError) do
      verifier.call(
        "Reader-Link.pdf",
        source_page_count: 7,
        expected_url: "https://example.test/rate"
      )
    end
  end

  test "preserves an inspection timeout instead of reporting a failed verification" do
    inspector = Object.new
    inspector.define_singleton_method(:call) { |*_, **_| raise PdfInspector::InspectionTimeout, "time expired" }

    assert_raises(PdfInspector::InspectionTimeout) do
      AnnotatedPdfVerifier.new(inspector: inspector).call("Reader-Link.pdf", source_page_count: 7, expected_url: "https://example.test/rate")
    end
  end

end
