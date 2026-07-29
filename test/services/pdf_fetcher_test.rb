require "test_helper"

class PdfFetcherTest < ActiveSupport::TestCase

  FakeResponse = Struct.new(:code, :headers, :chunks) do
    def [](name)
      headers[name.downcase]
    end

    def read_body
      chunks.each { |chunk| yield chunk }
    end
  end

  test "downloads a PDF into a bounded temporary file" do
    response = FakeResponse.new(
      "200",
      {
        "content-type" => "application/pdf",
        "content-length" => "8",
        "content-disposition" => 'attachment; filename="Reader.pdf"'
      },
      ["%PDF", "-1.7"]
    )

    download = fetcher_for(response).fetch

    assert_equal "%PDF-1.7", download.io.read
    assert_equal 8, download.content_length
    assert_equal "Reader.pdf", download.filename
  ensure
    download&.close
  end

  test "sanitizes a server supplied filename before it reaches the filesystem" do
    response = FakeResponse.new(
      "200",
      {
        "content-type" => "application/pdf",
        "content-length" => "5",
        "content-disposition" => 'attachment; filename="../../Reader $(touch escaped).pdf"'
      },
      ["%PDF-"]
    )

    download = fetcher_for(response).fetch

    assert_equal "Reader-(touch-escaped).pdf", download.filename
    assert_equal File.basename(download.filename), download.filename
    assert_not_includes download.filename, "/"
  ensure
    download&.close
  end

  test "rejects hosts resolving to private addresses" do
    fetcher = PdfFetcher.new(
      "http://example.test/Reader.pdf",
      resolver: ->(_host) { ["127.0.0.1"] },
      requester: ->(*) { flunk "private hosts must be rejected before the request" }
    )

    assert_raises(PdfFetcher::UnsafeAddress) { fetcher.fetch }
  end

  test "rejects redirects to private addresses" do
    responses = [
      FakeResponse.new("302", {"location" => "https://internal.test/Reader.pdf"}, []),
      FakeResponse.new("200", {"content-type" => "application/pdf"}, ["%PDF"])
    ]
    resolver = lambda do |host|
      host == "example.test" ? ["93.184.216.34"] : ["10.0.0.5"]
    end
    requester = lambda do |_uri, _address, &block|
      block.call(responses.shift)
    end

    fetcher = PdfFetcher.new(
      "https://example.test/Reader.pdf",
      resolver: resolver,
      requester: requester
    )

    assert_raises(PdfFetcher::UnsafeAddress) { fetcher.fetch }
  end

  test "rejects a redirect from HTTPS to cleartext HTTP" do
    response = FakeResponse.new(
      "302",
      {"location" => "http://example.test/Reader.pdf"},
      []
    )

    assert_raises(PdfFetcher::InvalidResponse) { fetcher_for(response).fetch }
  end

  test "enforces the download limit while streaming" do
    response = FakeResponse.new(
      "200",
      {"content-type" => "application/pdf"},
      ["1234", "5678"]
    )

    assert_raises(PdfFetcher::DownloadTooLarge) do
      fetcher_for(response, max_bytes: 7).fetch
    end
  end

  test "rejects non HTTP URLs and non PDF responses" do
    assert_raises(PdfFetcher::InvalidUrl) do
      PdfFetcher.new("file:///tmp/Reader.pdf").fetch
    end

    response = FakeResponse.new(
      "200",
      {"content-type" => "text/html", "content-length" => "4"},
      ["html"]
    )
    assert_raises(PdfFetcher::InvalidResponse) { fetcher_for(response).fetch }
  end

  test "rejects a response without a PDF header" do
    response = FakeResponse.new(
      "200",
      {"content-type" => "application/pdf", "content-length" => "4"},
      ["html"]
    )

    assert_raises(PdfFetcher::InvalidResponse) { fetcher_for(response).fetch }
  end

  private

  def fetcher_for(response, max_bytes: 1024)
    PdfFetcher.new(
      "https://example.test/Reader.pdf",
      max_bytes: max_bytes,
      resolver: ->(_host) { ["93.184.216.34"] },
      requester: ->(_uri, _address, &block) { block.call(response) }
    )
  end

end
