require "cgi"
require "ipaddr"
require "net/http"
require "openssl"
require "resolv"
require "tempfile"
require "timeout"
require "uri"

class PdfFetcher

  class Error < RuntimeError; end
  class InvalidUrl < Error; end
  class UnsafeAddress < Error; end
  class InvalidResponse < Error; end
  class AuthenticationRequired < InvalidResponse; end
  class DownloadUnavailable < InvalidResponse; end
  class NotPdf < InvalidResponse; end
  class DownloadTooLarge < Error; end

  Download = Struct.new(
    :io,
    :content_type,
    :content_length,
    :filename,
    :source_url,
    keyword_init: true
  ) do
    def close
      io.close! unless io.closed?
    end
  end

  DEFAULT_MAX_BYTES = 50 * 1024 * 1024
  DEFAULT_OPEN_TIMEOUT = 5
  DEFAULT_READ_TIMEOUT = 20
  DEFAULT_REDIRECT_LIMIT = 3

  BLOCKED_NETWORKS = %w[
    0.0.0.0/8
    10.0.0.0/8
    100.64.0.0/10
    127.0.0.0/8
    169.254.0.0/16
    172.16.0.0/12
    192.0.0.0/24
    192.0.2.0/24
    192.168.0.0/16
    198.18.0.0/15
    198.51.100.0/24
    203.0.113.0/24
    224.0.0.0/4
    240.0.0.0/4
    ::/128
    ::1/128
    ::ffff:0:0/96
    2001:db8::/32
    fc00::/7
    fe80::/10
    ff00::/8
  ].map { |network| IPAddr.new(network) }.freeze

  def initialize(
    url,
    max_bytes: Integer(ENV.fetch("RS_PDF_MAX_DOWNLOAD_BYTES", DEFAULT_MAX_BYTES)),
    open_timeout: Integer(ENV.fetch("RS_PDF_OPEN_TIMEOUT", DEFAULT_OPEN_TIMEOUT)),
    read_timeout: Integer(ENV.fetch("RS_PDF_READ_TIMEOUT", DEFAULT_READ_TIMEOUT)),
    redirect_limit: DEFAULT_REDIRECT_LIMIT,
    allow_private_networks: ENV["RS_PDF_ALLOW_PRIVATE_NETWORKS"] == "true",
    resolver: Resolv.method(:getaddresses),
    requester: nil
  )
    @url = url
    @max_bytes = max_bytes
    @open_timeout = open_timeout
    @read_timeout = read_timeout
    @redirect_limit = redirect_limit
    @allow_private_networks = allow_private_networks
    @resolver = resolver
    @requester = requester || method(:perform_request)
  end

  def fetch
    fetch_uri(parse_uri(@url), @redirect_limit)
  rescue URI::InvalidURIError => error
    raise InvalidUrl, "The publication URL is invalid: #{error.message}"
  end

  private

  def fetch_uri(uri, redirects_remaining)
    address = resolve_public_address(uri)
    download = nil

    @requester.call(uri, address) do |response|
      status = response.code.to_i

      if status.between?(300, 399)
        raise InvalidResponse, "Too many redirects while downloading the publication" if redirects_remaining.zero?

        location = response["location"]
        raise InvalidResponse, "The publication redirect has no location" if location.blank?

        redirect_uri = parse_uri(URI.join(uri.to_s, location).to_s)
        if uri.scheme == "https" && redirect_uri.scheme != "https"
          raise InvalidResponse, "The publication server attempted an insecure redirect"
        end

        return fetch_uri(redirect_uri, redirects_remaining - 1)
      end

      if [401, 403].include?(status)
        raise AuthenticationRequired, "The publication server requires an authenticated browser session"
      end

      unless status.between?(200, 299)
        raise DownloadUnavailable, "The publication server returned HTTP #{status}"
      end

      download = read_pdf_response(response, uri)
    end

    download || raise(InvalidResponse, "The publication server returned no response")
  end

  def parse_uri(value)
    uri = URI.parse(value.to_s)
    unless %w[http https].include?(uri.scheme&.downcase) && uri.host.present?
      raise InvalidUrl, "Only HTTP and HTTPS publication URLs are accepted"
    end
    raise InvalidUrl, "Publication URLs cannot contain credentials" if uri.userinfo.present?

    uri
  end

  def resolve_public_address(uri)
    addresses = @resolver.call(uri.host).uniq
    raise DownloadUnavailable, "The publication host could not be resolved" if addresses.empty?

    parsed_addresses = addresses.map { |address| IPAddr.new(address) }
    if !@allow_private_networks && parsed_addresses.any? { |address| blocked_address?(address) }
      raise UnsafeAddress, "The publication host resolves to a private or reserved address"
    end

    addresses.first
  rescue Resolv::ResolvError, IPAddr::InvalidAddressError
    raise DownloadUnavailable, "The publication host could not be resolved"
  end

  def blocked_address?(address)
    BLOCKED_NETWORKS.any? { |network| network.include?(address) }
  end

  def perform_request(uri, address)
    http = Net::HTTP.new(uri.host, uri.port, nil)
    http.ipaddr = address
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = @open_timeout
    http.read_timeout = @read_timeout
    http.write_timeout = @open_timeout

    request = Net::HTTP::Get.new(uri.request_uri)
    request["Accept"] = "application/pdf"
    request["User-Agent"] = "Readersourcing-RS_Server/2"

    http.start do |connection|
      connection.request(request) { |response| yield response }
    end
  rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error
    raise DownloadUnavailable, "The publication server timed out"
  rescue SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError => error
    raise DownloadUnavailable, "The publication could not be downloaded: #{error.message}"
  end

  def read_pdf_response(response, uri)
    content_type = response["content-type"].to_s.split(";").first.to_s.downcase

    declared_length = response["content-length"].to_i
    if declared_length > @max_bytes
      raise DownloadTooLarge, "The publication exceeds the configured download limit"
    end

    tempfile = Tempfile.new(["rs-server-publication-", ".pdf"])
    tempfile.binmode
    bytes_written = 0

    begin
      response.read_body do |chunk|
        bytes_written += chunk.bytesize
        if bytes_written > @max_bytes
          raise DownloadTooLarge, "The publication exceeds the configured download limit"
        end
        tempfile.write(chunk)
      end

      raise InvalidResponse, "The publication response is empty" if bytes_written.zero?
      if declared_length.positive? && declared_length != bytes_written
        raise InvalidResponse, "The publication response ended before its declared size"
      end

      tempfile.flush
      tempfile.rewind
      unless tempfile.read(1024).include?("%PDF-")
        raise NotPdf, "The publication response does not contain a PDF header"
      end
      tempfile.rewind

      Download.new(
        io: tempfile,
        content_type: content_type,
        content_length: bytes_written,
        filename: safe_filename(response["content-disposition"], uri),
        source_url: uri.to_s
      )
    rescue
      tempfile.close!
      raise
    end
  end

  def safe_filename(content_disposition, uri)
    candidate = disposition_filename(content_disposition)
    candidate ||= CGI.unescape(File.basename(uri.path.to_s))
    candidate = File.basename(candidate.to_s.tr("\\", "/"))
    candidate = candidate.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    candidate = candidate.delete("\0").gsub(/[[:cntrl:]]/, "")
    candidate = candidate.gsub(/[^\p{Alnum}_.()\-]+/u, "-")
    candidate = candidate.sub(/\A[.\-]+/, "")

    stem = candidate.sub(/\.pdf\z/i, "")
    stem = "publication" if stem.blank?
    "#{stem}.pdf"
  end

  def disposition_filename(header)
    return if header.blank?

    encoded = header.match(/filename\*\s*=\s*UTF-8''([^;]+)/i)&.captures&.first
    return CGI.unescape(encoded.delete_prefix('"').delete_suffix('"')) if encoded.present?

    quoted = header.match(/filename\s*=\s*"([^"]+)"/i)&.captures&.first
    quoted || header.match(/filename\s*=\s*([^;]+)/i)&.captures&.first&.strip
  end

end
