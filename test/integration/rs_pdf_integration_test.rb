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
    rating_url = "https://example.test/rate/1/token"

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
    end
  end
end
