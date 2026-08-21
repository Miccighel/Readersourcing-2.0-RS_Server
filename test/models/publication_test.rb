require "test_helper"
require "tempfile"
require "tmpdir"

class PublicationTest < ActiveSupport::TestCase

	setup do
		@storage_root = Dir.mktmpdir("rs-server-publications-")
		@previous_storage_root = ENV["RS_PDF_STORAGE_ROOT"]
		ENV["RS_PDF_STORAGE_ROOT"] = @storage_root
	end

	teardown do
		@previous_storage_root.nil? ? ENV.delete("RS_PDF_STORAGE_ROOT") : ENV["RS_PDF_STORAGE_ROOT"] = @previous_storage_root
		FileUtils.remove_entry(@storage_root) if File.exist?(@storage_root)
	end

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
    captured_url = nil
    runner.define_singleton_method(:call) do |expected_output:, url:, **_arguments|
      captured_url = url
      FileUtils.cp(source_pdf, expected_output)
      RsPdfRunner::Result.new(stdout: "converted", stderr: "", status: nil)
    end
    verifier = Object.new
    verifier.define_singleton_method(:call) { |*_, **_| true }
    preparer = PdfPreparation.new(runner: runner, verifier: verifier)
    publication.define_singleton_method(:pdf_fetcher) { fetcher }
    publication.define_singleton_method(:pdf_preparer) { preparer }

    request_data = {
      host: "https://readersourcing.example",
      user: user
    }

    publication.fetch(request_data)

    assert_equal "Reader.pdf", publication.reload.pdf_name
    assert_equal "Reader-Link.pdf", publication.pdf_name_link
    assert_path_exists publication.send(:absolute_pdf_download_path_link, user)
    assert publication.send(:absolute_pdf_download_path_link, user).to_s.start_with?(@storage_root)
    refute publication.send(:absolute_pdf_download_path_link, user).to_s.start_with?(Rails.public_path.to_s)
    assert_not File.exist?(publication.send(:absolute_pdf_download_path, user))
    reference = Rack::Utils.unescape_path(URI.parse(captured_url).path.split("/").last)
    assert_equal user, PaperRatingReference.resolve(reference, publication: publication)
  ensure
    publication&.remove_files(user) if user
    temporary_pdf&.close! unless temporary_pdf&.closed?
  end

end
