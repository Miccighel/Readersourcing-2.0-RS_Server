require "test_helper"
require "socket"

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

  test "accepts a valid PDF even when the server reports a generic content type" do
    response = FakeResponse.new(
      "200",
      {"content-type" => "application/octet-stream", "content-length" => "8"},
      ["%PDF-1.7"]
    )

    download = fetcher_for(response).fetch

    assert_equal "application/octet-stream", download.content_type
    assert_equal "%PDF-1.7", download.io.read
  ensure
    download&.close
  end

  test "reports when the publication requires an authenticated browser session" do
    response = FakeResponse.new("403", {"content-type" => "text/html"}, [])

    assert_raises(PdfFetcher::AuthenticationRequired) { fetcher_for(response).fetch }
  end

  test "a continuous slow response cannot renew the download deadline" do
    server = TCPServer.new("127.0.0.1", 0)
    connection = nil
    sent_chunks = Queue.new
    worker = Thread.new do
      connection = server.accept
      loop { break if connection.gets == "\r\n" }
      connection.write("HTTP/1.1 200 OK\r\nContent-Type: application/pdf\r\nTransfer-Encoding: chunked\r\n\r\n")
      loop do
        connection.write("6\r\n%PDF-1\r\n")
        sent_chunks << true
        sleep 0.05
      end
    rescue IOError, SystemCallError
      nil
    end
    before = Dir.glob(File.join(Dir.tmpdir, "rs-server-publication-*.pdf"))
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    fetcher = PdfFetcher.new(
      "http://127.0.0.1:#{server.addr[1]}/Reader.pdf", allow_private_networks: true,
      read_timeout: 1, timeout: 0.3
    )

    assert_raises(PdfFetcher::DownloadTimeout) { fetcher.fetch }
    assert_operator sent_chunks.size, :>=, 2
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 2
    assert_equal before, Dir.glob(File.join(Dir.tmpdir, "rs-server-publication-*.pdf"))
  ensure
    connection&.close
    server&.close
    worker&.kill
    worker&.join
  end

  test "redirects and response streaming share one monotonic budget" do
    now = 10.0
    deadline = PdfOperationDeadline.new(timeout: 1, clock: -> { now })
    requests = 0
    response = FakeResponse.new("302", {"location" => "/Next.pdf"}, [])
    fetcher = PdfFetcher.new(
      "https://example.test/Reader.pdf", resolver: ->(_) { ["93.184.216.34"] },
      requester: ->(_uri, _address, &block) { requests += 1; now += 0.6; block.call(response) }
    )

    assert_raises(PdfFetcher::DownloadTimeout) { fetcher.fetch(deadline: deadline) }
    assert_equal 2, requests
  end

  test "bounds host resolution before opening a connection" do
    fetcher = PdfFetcher.new(
      "https://example.test/Reader.pdf", timeout: 0.1,
      resolver: ->(_) { sleep 20 }, requester: ->(*) { flunk "No request must be opened" }
    )

    assert_raises(PdfFetcher::DownloadTimeout) { fetcher.fetch }
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
