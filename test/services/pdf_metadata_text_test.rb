require "minitest/autorun"
require_relative "../../app/services/pdf_metadata_text"

class PdfMetadataTextTest < Minitest::Test

  def test_decodes_the_pdf_doc_title_without_changing_the_inspected_metadata
    path = File.expand_path("../fixtures/files/Reader.pdf", __dir__)
    value = PDF::Reader.new(path).info.fetch(:Title)
    original = value.dup
    refute value.valid_encoding?

    result = PdfMetadataText.decode(value.freeze)

    assert_equal "Readersourcing—a manifesto", result
    assert_equal Encoding::UTF_8, result.encoding
    assert result.valid_encoding?
    assert_equal original.bytes, value.bytes
    assert_equal original.encoding, value.encoding
  end

  def test_preserves_valid_unicode_text
    ["Reader", "Café — 日本語 😀", "Café".b].each do |value|
      result = PdfMetadataText.decode(value.freeze)

      assert_equal value.b, result.b
      assert_equal Encoding::UTF_8, result.encoding
      assert result.valid_encoding?
    end
  end

  def test_uses_pdf_doc_encoding_for_legacy_accented_text
    assert_equal "Café—Reader", PdfMetadataText.decode("Caf\xe9\x84Reader".b)
  end

  def test_keeps_absent_and_non_text_values_unchanged
    [nil, 42, [:name], {Title: "Reader"}].each do |value|
      assert_same value, PdfMetadataText.decode(value)
    end
  end

end
