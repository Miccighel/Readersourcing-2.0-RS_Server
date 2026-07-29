require "test_helper"
require "tempfile"

class PublicationTest < ActiveSupport::TestCase

  test "normalizes a PDF name before constructing storage paths" do
    assert_equal "Reader", Publication.safe_pdf_stem("../../Reader.pdf")
    assert_equal "Reader-(touch)", Publication.safe_pdf_stem('Reader $(touch).PDF')
    assert_equal "publication", Publication.safe_pdf_stem("../.pdf")
  end

  test "fetch delegates bounded download and process execution to infrastructure services" do
    publication = publications(:one)
    user = users(:one)
    temporary_pdf = Tempfile.new(["publication-test-", ".pdf"])
    temporary_pdf.binmode
    FileUtils.cp(file_fixture("Reader.pdf"), temporary_pdf.path)
    temporary_pdf.rewind

    download = PdfFetcher::Download.new(
      io: temporary_pdf,
      content_type: "application/pdf",
      content_length: File.size(temporary_pdf.path),
      filename: "Reader.pdf",
      source_url: publication.pdf_url
    )
    fetcher = Struct.new(:download) do
      def fetch
        download
      end
    end.new(download)
    runner = Object.new
    source_pdf = file_fixture("Reader.pdf")
    runner.define_singleton_method(:call) do |expected_output:, **_arguments|
      FileUtils.cp(source_pdf, expected_output)
      RsPdfRunner::Result.new(stdout: "converted", stderr: "", status: nil)
    end
    publication.define_singleton_method(:pdf_fetcher) { fetcher }
    publication.define_singleton_method(:rs_pdf_runner) { runner }

    request_data = {
      authToken: "encrypted-token",
      host: "https://readersourcing.example",
      user: user
    }

    publication.fetch(request_data)

    assert_equal "Reader.pdf", publication.reload.pdf_name
    assert_equal "Reader-Link.pdf", publication.pdf_name_link
    assert_path_exists publication.send(:absolute_pdf_download_path_link, user)
    assert_not File.exist?(publication.send(:absolute_pdf_download_path, user))
  ensure
    publication&.remove_files(user) if user
    temporary_pdf&.close! unless temporary_pdf&.closed?
  end

end
