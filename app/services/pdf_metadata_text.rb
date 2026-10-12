require "pdf/reader"

class PdfMetadataText

  def self.decode(value)
    return value unless value.is_a?(String)

    text = value.dup.force_encoding(Encoding::UTF_8)
    return text if text.valid_encoding?

    PDF::Reader::Encoding.new(:PDFDocEncoding).to_utf8(value)
  end

end
