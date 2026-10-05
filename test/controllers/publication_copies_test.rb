require "test_helper"
require "tmpdir"
require "stringio"

class PublicationCopiesTest < ActionDispatch::IntegrationTest

  setup do
    @publication = publications(:one)
    @user = users(:one)
    @headers = api_headers_for(@user)
    @storage_root = Dir.mktmpdir("rs-copy-api-")
    @previous_storage_root = ENV["RS_PDF_STORAGE_ROOT"]
    ENV["RS_PDF_STORAGE_ROOT"] = @storage_root
    @source = File.binread(file_fixture("Reader.pdf"))
  end

  teardown do
    @previous_storage_root.nil? ? ENV.delete("RS_PDF_STORAGE_ROOT") : ENV["RS_PDF_STORAGE_ROOT"] = @previous_storage_root
    FileUtils.remove_entry_secure(@storage_root)
  end

  test "two readers can download their own originals and annotated copies using different filenames" do
    paths_before = @publication.attributes.slice("pdf_name", "pdf_name_link", "pdf_storage_path", "pdf_download_path", "pdf_download_path_link")
    first = upload("First.pdf", @source, @headers)
    second_user = users(:two)
    second_source = @source + "\n% second reader source\n"
    second = upload("Second.pdf", second_source, api_headers_for(second_user))

    assert_equal "First.pdf", first.fetch("pdf_name")
    assert_equal "Second.pdf", second.fetch("pdf_name")
    assert_not_equal first.fetch("pdf_storage_path"), second.fetch("pdf_storage_path")
    assert_equal paths_before, @publication.reload.attributes.slice(*paths_before.keys)

    get_download(first.fetch("pdf_download_url"))
    assert_equal @source, response.body
    assert_includes response.headers.fetch("Content-Disposition"), "First.pdf"
    get_download(second.fetch("pdf_download_url"))
    assert_equal second_source, response.body

    [first, second].zip([@user, second_user]).each do |result, reader|
      get_download(result.fetch("pdf_download_url_link"))
      annotated = PDF::Reader.new(StringIO.new(response.body))
      assert_equal PDF::Reader.new(StringIO.new(@source)).page_count + 1, annotated.page_count
      reference = Rack::Utils.unescape_path(URI.parse(annotated.info.fetch(:BaseUrl)).path.split("/").last)
      assert_equal reader, PaperRatingReference.resolve(reference, publication: @publication)
    end

    get is_saved_for_later_publication_path(@publication, format: :json), headers: @headers
    assert_response :success
    assert_equal "First-Link.pdf", response.parsed_body.fetch("pdf_name_link")
    assert_equal "complete", response.parsed_body.fetch("preparation_status")
    get_download(response.parsed_body.fetch("pdf_download_url_link"))
  end

  test "an old signed download remains bound to its bytes when the same filename is prepared again" do
    first = upload("Reader.pdf", @source, @headers)
    replacement_source = @source + "\n% replacement source\n"
    replacement = upload("Reader.pdf", replacement_source, @headers)

    assert_not_equal first.fetch("pdf_download_url"), replacement.fetch("pdf_download_url")
    get_download(first.fetch("pdf_download_url"))
    assert_equal @source, response.body
    get_download(replacement.fetch("pdf_download_url"))
    assert_equal replacement_source, response.body
    get_download(first.fetch("pdf_download_url_link"))
    assert_equal PDF::Reader.new(StringIO.new(@source)).page_count + 1, PDF::Reader.new(StringIO.new(response.body)).page_count
  end

  test "a rejected refresh leaves the published pair and the publication metadata unchanged" do
    first = upload("Reader.pdf", @source, @headers)
    before = @publication.reload.attributes
    current = PublicationCopy.current(publication: @publication, user: @user)
    error = AnnotatedPdfVerifier::VerificationError.new("Verification failed")
    verifier = Object.new
    verifier.define_singleton_method(:call) { |*_, **_| raise error }

    AnnotatedPdfVerifier.stub(:new, ->(*) { verifier }) do
      post fetch_upload_publications_path(format: :json),
        params: {publication: {pdf_url: @publication.pdf_url}, file: uploaded_file("Failed.pdf", @source)},
        headers: @headers
    end

    assert_response :unprocessable_entity
    assert_equal "verification_failed", response.parsed_body.fetch("status")
    assert_equal before, @publication.reload.attributes
    assert_equal current.generation, PublicationCopy.current(publication: @publication, user: @user).generation
    get_download(first.fetch("pdf_download_url"))
    assert_equal @source, response.body
    get_download(first.fetch("pdf_download_url_link"))
    assert_empty current.root.glob("rs-copy-*")
  end

  test "legacy copies expose only downloads for files that actually exist" do
    legacy = PublicationCopy.legacy(publication: @publication, user: @user)
    FileUtils.mkdir_p(legacy.directory)
    FileUtils.cp(file_fixture("Reader.pdf"), legacy.directory.join("Own-Link.pdf"))

    get is_saved_for_later_publication_path(@publication, format: :json), headers: @headers

    assert_response :success
    assert_equal "Own-Link.pdf", response.parsed_body.fetch("pdf_name_link")
    assert_equal "complete", response.parsed_body.fetch("preparation_status")
    assert_nil response.parsed_body.fetch("pdf_download_url")
    assert_nil response.parsed_body.fetch("pdf_download_path")
    get_download(response.parsed_body.fetch("pdf_download_url_link"))
    assert_equal @source, response.body
  end

  test "a timed out refresh retains both current files, metadata, and already issued downloads" do
    first = upload("Reader.pdf", @source, @headers)
    before = @publication.reload.attributes
    current = PublicationCopy.current(publication: @publication, user: @user)
    previous_timeout = ENV["RS_PDF_TOTAL_TIMEOUT"]
    ENV["RS_PDF_TOTAL_TIMEOUT"] = "0.02"

    post fetch_upload_publications_path(format: :json),
      params: {publication: {pdf_url: @publication.pdf_url}, file: uploaded_file("Failed.pdf", @source)}, headers: @headers

    assert_response :unprocessable_entity
    assert_equal "processing_timeout", response.parsed_body.fetch("status")
    assert_equal before, @publication.reload.attributes
    assert_equal current.generation, PublicationCopy.current(publication: @publication, user: @user).generation
    assert_equal [current.generation], current.root.join("generations").children.map { |path| path.basename.to_s }
    assert_empty current.root.glob("rs-copy-*")
    get_download(first.fetch("pdf_download_url"))
    assert_equal @source, response.body
    get_download(first.fetch("pdf_download_url_link"))
  ensure
    previous_timeout.nil? ? ENV.delete("RS_PDF_TOTAL_TIMEOUT") : ENV["RS_PDF_TOTAL_TIMEOUT"] = previous_timeout
  end

  test "publication response fields and both references use one copy snapshot" do
    upload("First.pdf", @source, @headers)
    first = PublicationCopy.current(publication: @publication, user: @user)
    upload("Second.pdf", @source, @headers)
    second = PublicationCopy.current(publication: @publication, user: @user)
    reads = 0
    changing_copy = lambda do |**_arguments|
      reads += 1
      reads == 1 ? first : second
    end

    PublicationCopy.stub(:current, changing_copy) do
      get publication_path(@publication, format: :json), headers: @headers
    end

    assert_response :success
    assert_equal 1, reads
    result = response.parsed_body
    assert_equal "First.pdf", result.fetch("pdf_name")
    assert_equal "First-Link.pdf", result.fetch("pdf_name_link")
    get_download(result.fetch("pdf_download_url"))
    assert_includes response.headers.fetch("Content-Disposition"), "First.pdf"
    get_download(result.fetch("pdf_download_url_link"))
    assert_includes response.headers.fetch("Content-Disposition"), "First-Link.pdf"
  end

  test "account removal removes only that reader's copies and revokes their downloads" do
    first = upload("First.pdf", @source, @headers)
    second = upload("Second.pdf", @source, api_headers_for(users(:two)))

    delete user_path(@user, format: :json), headers: @headers, as: :json

    assert_response :success
    assert_not File.exist?(File.join(@storage_root, "user", @user.id.to_s))
    get URI.parse(first.fetch("pdf_download_url_link")).request_uri
    assert_response :not_found
    get_download(second.fetch("pdf_download_url_link"))
  end

  private

  def uploaded_file(filename, contents)
    Rack::Test::UploadedFile.new(StringIO.new(contents), "application/pdf", true, original_filename: filename)
  end

  def upload(filename, contents, headers)
    post fetch_upload_publications_path(format: :json),
      params: {publication: {pdf_url: @publication.pdf_url}, file: uploaded_file(filename, contents)},
      headers: headers
    assert_response :success
    response.parsed_body
  end

  def get_download(url)
    get URI.parse(url).request_uri
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
  end

end
