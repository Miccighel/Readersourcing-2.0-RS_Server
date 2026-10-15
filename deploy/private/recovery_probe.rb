# Executed by rails runner only inside the isolated restored application.
require "digest"
require "json"
require "uri"
require "rack/mock"

origin = ENV.fetch("PUBLIC_BASE_URL")
raise "Unexpected recovery origin" unless origin == "http://127.0.0.1:33030"
raise "Unexpected recovery project" unless ENV.fetch("RS_RECOVERY_PROJECT").match?(/\Ars-recovery-[0-9a-f]{12}\z/)

user = User.find(3)
publication = Publication.find(5)
copy = publication.copy_for(user)
raise "Restored PDF pair is missing" unless copy && %w[original annotated].all? { |variant| copy.available?(variant) }

client = Rack::MockRequest.new(Rails.application)
request = ->(path) { client.get(path, "HTTP_HOST" => URI(origin).authority, "SERVER_NAME" => "127.0.0.1", "SERVER_PORT" => "33030", "REMOTE_ADDR" => "127.0.0.1", "rack.url_scheme" => "http") }
raise "Restored application is not ready" unless request.call("/ready").status == 200
raise "Restored login is unavailable" unless request.call("/login").status == 200

downloads = %w[original annotated].to_h do |variant|
  url = variant == "original" ? publication.pdf_download_url(origin, user, copy: copy) : publication.pdf_download_url_link(origin, user, copy: copy)
  response = request.call(URI(url).request_uri)
  raise "Restored download failed" unless response.status == 200 && response.content_type.to_s.split(";").first == "application/pdf"
  expected = Digest::SHA256.file(copy.path(variant)).hexdigest
  raise "Restored download bytes differ" unless Digest::SHA256.hexdigest(response.body) == expected
  [variant, {"status" => 200, "sha256" => expected}]
end

metadata = PdfInspector.new.call(copy.path("annotated").to_s, allow_annotated: true).metadata
uri = URI(metadata.fetch(:BaseUrl))
raise "Restored paper origin differs" unless "#{uri.scheme}://#{uri.authority}" == origin && !uri.query && !uri.fragment
match = PdfRatingUrlExtractor::RATING_PATH.match(uri.path)
raise "Restored paper path differs" unless match && match[1].to_i == publication.id
reference = Rack::Utils.unescape_path(match[2])
raise "Restored signing key cannot resolve the original paper reference" unless PaperRatingReference.resolve(reference, publication: publication) == user
response = request.call(uri.request_uri)
raise "Anonymous paper access must require login" unless response.status == 200 && response.body.include?('id="login-form"')

File.open(ENV.fetch("RS_RECOVERY_REPORT_PATH", "/tmp/recovery-probe.json"), "wx", 0o600) do |file|
  file.write(JSON.pretty_generate(
    "status" => "passed", "readiness" => true, "login_page" => true, "downloads" => downloads,
    "existing_paper_reference_verified" => true, "paper_reference_requires_login" => true,
    "public_origin_preserved" => true, "external_http_requests" => false,
    "authentication_tokens_issued" => false, "ratings_submitted" => false,
    "scope" => "Rack requests inside the restored application; not a browser test or access to the running source",
    "publication_copy_leases" => "May be renewed in the isolated volume by normal signed download URL issuance"
  ) + "\n")
end
