require "uri"

class PdfRatingUrlExtractor

  class Error < RuntimeError; end

  RATING_PATH = %r{\A/rate/([1-9][0-9]*)/([^/]+)\z}.freeze

  def initialize(inspector: PdfInspector.new)
    @inspector = inspector
  end

  def call(file, user:, host:)
    download = PdfUpload.new(file).fetch
    document = @inspector.call(download.io.path, allow_annotated: true)
    base_url = document.metadata[:BaseUrl]
    raise Error, I18n.t("errors.messages.base_url_not_found") if base_url.blank?

    validate_rating_url(base_url, user: user, host: host)
  ensure
    download&.close
  end

  private

  def validate_rating_url(base_url, user:, host:)
    raise_invalid_reference unless base_url.is_a?(String)

    uri = URI.parse(base_url)
    origin = URI.parse(PublicBaseUrl.new(host).to_s)
    unless uri.is_a?(URI::HTTP) && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
      raise_invalid_reference
    end
    unless uri.scheme == origin.scheme && uri.host&.casecmp?(origin.host) && uri.port == origin.port
      raise Error, I18n.t("errors.messages.publication_fetched_somewhere_else")
    end

    path = RATING_PATH.match(uri.path)
    raise_invalid_reference unless path

    publication = Publication.find_by(id: path[1])
    raise_invalid_reference unless publication

    reference = Rack::Utils.unescape_path(path[2])
    reference_user = PaperRatingReference.resolve(reference, publication: publication)
    raise_invalid_reference unless reference_user
    unless reference_user == user
      raise Error, I18n.t("errors.messages.not_the_same_user")
    end

    base_url
  rescue URI::InvalidURIError, ArgumentError
    raise_invalid_reference
  end

  def raise_invalid_reference
    raise Error, I18n.t("errors.messages.invalid_paper_reference")
  end

end
