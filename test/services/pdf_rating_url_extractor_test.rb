require "test_helper"
require "tempfile"

class PdfRatingUrlExtractorTest < ActiveSupport::TestCase

  UploadedFile = Struct.new(:tempfile, :original_filename, :content_type)

  setup do
    @user = users(:one)
    @publication = publications(:two)
    @host = "https://readersourcing.example"
    @reference = PaperRatingReference.issue(user: @user, publication: @publication)
    @url = rating_url(@reference)
    @source = Tempfile.new(["rating-url-source-", ".pdf"])
    @source.binmode
    FileUtils.cp(file_fixture("Reader.pdf"), @source.path)
    @source.rewind
    @file = UploadedFile.new(@source, "../../Reader.pdf", "application/octet-stream")
  end

  teardown do
    @source.close!
  end

  test "returns a rating URL for the authenticated reader and removes its temporary copy" do
    assert_equal @url, extract(@url)
    assert_not File.exist?(@copied_path)
    assert_not @source.closed?
    assert_not File.exist?(Publication.absolute_pdf_storage_temp_path(@user))
  end

  test "compares scheme host and effective port rather than URL substrings" do
    assert_equal @url.sub(@host, "https://READERSOURCING.example:443"),
      extract(@url.sub(@host, "https://READERSOURCING.example:443"))

    [
      "https://untrusted.example/?next=#{@url}",
      @url.sub(@host, "https://readersourcing.example.untrusted.example"),
      @url.sub(@host, "https://untrusted.example") + "##{@host}",
      @url.sub(@host, "http://readersourcing.example"),
      @url.sub(@host, "https://readersourcing.example:444"),
      @url.sub(@host, "https://reader@readersourcing.example")
    ].each do |url|
      assert_rejected(url)
    end
  end

  test "requires the rating route without query fragment or additional path segments" do
    [
      @url.sub("/rate/", "/publications/"),
      "#{@url}/extra",
      "#{@url}?next=https://untrusted.example",
      "#{@url}#other-page",
      "#{@host}/rate/#{@publication.id}/",
      @url.sub("/rate/#{@publication.id}/", "/rate/0/"),
      "javascript:alert(1)",
      "not a URL",
      42
    ].each do |url|
      assert_rejected(url)
    end
  end

  test "rejects missing metadata and invalid or mismatched publication references" do
    [nil, "", rating_url("#{@reference}altered"),
      rating_url(@reference, publication: publications(:one)),
      "#{@host}/rate/2147483647/#{ERB::Util.url_encode(@reference)}"
    ].each do |url|
      assert_rejected(url)
    end
  end

  test "rejects a reference issued for another reader" do
    reference = PaperRatingReference.issue(user: users(:two), publication: @publication)
    error = assert_rejected(rating_url(reference))

    assert_equal I18n.t("errors.messages.not_the_same_user"), error.message
  end

  test "keeps a paper reference usable after logout and without automatic expiration" do
    @user.authentication_tokens.delete_all

    travel 1.year do
      assert_equal @url, extract(@url)
    end
  end

  test "accepts a legacy reference only during its original token lifetime" do
    token = JsonWebToken.encode({user_id: @user.id}, 1.hour.from_now)
    key_length = ActiveSupport::MessageEncryptor.key_len
    salt = SecureRandom.hex(key_length)
    key = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(salt, key_length)
    encrypted_token = ActiveSupport::MessageEncryptor.new(key).encrypt_and_sign(token)
    url = rating_url("#{salt}!!!!!#{encrypted_token}")

    assert_equal url, extract(url)
    travel 2.hours do
      assert_rejected(url)
    end
  end

  test "removes its temporary copy when PDF inspection fails" do
    inspector = Object.new
    inspector.define_singleton_method(:call) do |path, **_options|
      @path = path
      raise PdfInspector::MalformedPdf, "Invalid document"
    end

    assert_raises(PdfInspector::MalformedPdf) do
      PdfRatingUrlExtractor.new(inspector: inspector).call(@file, user: @user, host: @host)
    end
    assert_not File.exist?(inspector.instance_variable_get(:@path))
  end

  test "enforces the shared upload size limit before inspecting metadata" do
    previous_limit = ENV["RS_PDF_MAX_DOWNLOAD_BYTES"]
    ENV["RS_PDF_MAX_DOWNLOAD_BYTES"] = "7"

    assert_raises(PdfUpload::UploadTooLarge) do
      PdfRatingUrlExtractor.new.call(@file, user: @user, host: @host)
    end
    assert_not File.exist?(Publication.absolute_pdf_storage_temp_path(@user))
  ensure
    previous_limit.nil? ? ENV.delete("RS_PDF_MAX_DOWNLOAD_BYTES") : ENV["RS_PDF_MAX_DOWNLOAD_BYTES"] = previous_limit
  end

  test "opens the actual uploaded content as a PDF rather than trusting its content type" do
    @source.truncate(0)
    @source.write("%PDF-this is not a document")
    @source.flush

    assert_raises(PdfInspector::MalformedPdf) do
      PdfRatingUrlExtractor.new.call(@file, user: @user, host: @host)
    end
  end

  private

  def rating_url(reference, publication: @publication)
    @host + Rails.application.routes.url_helpers.rate_paper_path(publication.id, reference)
  end

  def extract(url)
    inspector = Object.new
    inspector.define_singleton_method(:call) do |path, allow_annotated:, **_options|
      raise "Expected annotation inspection" unless allow_annotated
      @path = path
      PdfInspector::Document.new(metadata: {BaseUrl: url}, page_count: 8)
    end
    PdfRatingUrlExtractor.new(inspector: inspector).call(@file, user: @user, host: @host)
  ensure
    @copied_path = inspector.instance_variable_get(:@path)
  end

  def assert_rejected(url)
    error = assert_raises(PdfRatingUrlExtractor::Error) { extract(url) }
    assert_not File.exist?(@copied_path)
    error
  end

end
