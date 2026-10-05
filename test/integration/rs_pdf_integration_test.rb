require "test_helper"
require "open3"
require "tmpdir"

class RsPdfIntegrationTest < ActiveSupport::TestCase
  setup do
    @publication = publications(:one)
  end

  test "bundled RS_PDF preserves the server subprocess contract" do
    jar_path = @publication.send(:absolute_rs_pdf_path)
    input_path = file_fixture("Reader.pdf")
    source_reader = PDF::Reader.new(input_path)
    user = users(:one)
    reference = PaperRatingReference.issue(user: user, publication: @publication)
    rating_url = "https://example.test" + Rails.application.routes.url_helpers.rate_paper_path(@publication.id, reference)

    assert_equal Rails.root.join("lib", "RS_PDF-v2.0.0-shaded.jar"), jar_path
    assert_predicate jar_path, :file?

    Dir.mktmpdir("rs_pdf_server_test") do |output_path|
      stdout, stderr, status = Open3.capture3(
        "java", "-jar", jar_path.to_s,
        "-pIn", input_path.to_s,
        "-pOut", output_path,
        "-u", rating_url,
        "-c", "Express your rating"
      )

      assert status.success?, [stdout, stderr].reject(&:empty?).join("\n")

      annotated_path = File.join(output_path, "Reader-Link.pdf")
      annotated_reader = PDF::Reader.new(annotated_path)

      assert_path_exists annotated_path
      assert_equal source_reader.page_count + 1, annotated_reader.page_count
      assert_equal rating_url, annotated_reader.info[:BaseUrl]
      assert_not File.exist?(File.join(output_path, "Reader-QRCode.png"))

      File.open(annotated_path, "rb") do |file|
        upload = Struct.new(:tempfile, :original_filename, :content_type).new(file, "Reader-Link.pdf", "application/pdf")
        assert_equal rating_url, Publication.extract_base_url(upload, user, host: "https://example.test")
      end
    end
  end

  test "bundled RS_PDF exposes an unsuccessful process status" do
    jar_path = @publication.send(:absolute_rs_pdf_path)
    input_path = file_fixture("Reader.pdf")

    Dir.mktmpdir("rs_pdf_server_failure_test") do |output_path|
      runner = RsPdfRunner.new(jar_path: jar_path)
      error = assert_raises(RsPdfRunner::ExecutionError) do
        runner.call(
          input_path: input_path,
          output_path: output_path,
          url: "file:///tmp/rate",
          caption: "Express your rating",
          expected_output: File.join(output_path, "Reader-Link.pdf")
        )
      end

      assert_includes error.message, "exit status 2"
      assert_not File.exist?(File.join(output_path, "Reader-Link.pdf"))
    end
  end
end
