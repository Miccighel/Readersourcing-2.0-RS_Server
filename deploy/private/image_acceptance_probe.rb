# Run through rails runner on stdin, only in the empty isolated acceptance database.
require "digest"
require "json"
require "securerandom"
require "uri"
require "rack/mock"

origin = ENV.fetch("PUBLIC_BASE_URL")
project = ENV.fetch("RS_IMAGE_ACCEPTANCE_PROJECT")
raise "Unexpected acceptance environment" unless Rails.env.production? && origin == "http://127.0.0.1:33030" &&
  project.match?(/\Ars-private-[0-9a-f]{12}\z/) && project != "rs-private-8955233c3d65"
raise "Acceptance requires an empty database" unless [User, Publication, Rating, AuthenticationToken].all? { |model| model.count.zero? }
fixture = "/acceptance/Reader.pdf"
fixture_sha = "0804774bb87edd869a95141f00bc6c3559e4b6df3b7b94412c10c9a7f6e8dfab"
raise "Unexpected acceptance fixture" unless Digest::SHA256.file(fixture).hexdigest == fixture_sha

client = Rack::MockRequest.new(Rails.application)
environment = {"HTTP_HOST" => "127.0.0.1:33030", "SERVER_NAME" => "127.0.0.1", "SERVER_PORT" => "33030",
  "REMOTE_ADDR" => "127.0.0.1", "rack.url_scheme" => "http"}
request = ->(method, path, options = {}) { client.public_send(method, path, environment.merge(options)) }
raise "Application is not ready" unless request.call(:get, "/ready").status == 200
login = request.call(:get, "/login")
raise "Login page is unavailable" unless login.status == 200 && login.body.include?('id="login-form"')

password = SecureRandom.hex(32)
user = User.create!(first_name: "Image", last_name: "Acceptance", email: "reader-#{SecureRandom.hex(6)}@image-check.test",
  password: password, email_confirmed: true, subscribe: false)
missing_title = Publication.create!(pdf_url: "https://image-check.test/not-prepared.pdf", title: nil)
response = request.call(:post, "/authenticate.json", "CONTENT_TYPE" => "application/json",
  input: JSON.generate(email: user.email, password: password))
raise "Authentication failed" unless response.status == 200
token = JSON.parse(response.body).fetch("auth_token")
cookie = Array(response["set-cookie"]).flat_map { |value| value.split("\n") }.map { |value| value.split(";", 2).first }.join("; ")
raise "Authentication session is absent" if cookie.empty?
session = {"HTTP_COOKIE" => cookie}
authorization = {"HTTP_AUTHORIZATION" => "Bearer #{token}"}
list = request.call(:get, "/publications/list", session)
raise "Missing title presentation failed" unless list.status == 200 && list.body.include?("Title not available") && missing_title.reload.title.nil?

boundary = "RSImageAcceptance#{SecureRandom.hex(16)}"
body = "--#{boundary}\r\nContent-Disposition: form-data; name=\"publication[pdf_url]\"\r\n\r\nhttps://image-check.test/Reader.pdf\r\n".b
body << "--#{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"Reader.pdf\"\r\nContent-Type: application/pdf\r\n\r\n".b
body << File.binread(fixture) << "\r\n--#{boundary}--\r\n".b
response = request.call(:post, "/publications/fetch_upload.json", authorization.merge(
  "CONTENT_TYPE" => "multipart/form-data; boundary=#{boundary}", input: body))
raise "PDF upload or annotation failed" unless response.status == 201
prepared = JSON.parse(response.body)
publication = Publication.find(prepared.fetch("id"))
raise "Prepared metadata differs" unless publication.title == "Readersourcing—a manifesto" && prepared.fetch("preparation_status") == "complete"
copy = publication.copy_for(user)
raise "Prepared PDF pair is incomplete" unless copy && %w[original annotated].all? { |variant| copy.available?(variant) }
downloads = %w[original annotated].to_h do |variant|
  url = prepared.fetch(variant == "original" ? "pdf_download_url" : "pdf_download_url_link")
  uri = URI(url)
  raise "Unexpected download origin" unless "#{uri.scheme}://#{uri.authority}" == origin
  result = request.call(:get, uri.request_uri)
  expected = Digest::SHA256.file(copy.path(variant)).hexdigest
  raise "PDF download failed" unless result.status == 200 && result.content_type.to_s.split(";").first == "application/pdf" &&
    Digest::SHA256.hexdigest(result.body) == expected && result["cache-control"].include?("no-store") && result["x-content-type-options"] == "nosniff"
  raise "Original PDF changed" if variant == "original" && expected != fixture_sha
  [variant, {"status" => 200, "sha256" => expected}]
end
opened = request.call(:get, "/publications/#{publication.id}/open", session)
raise "Open navigation failed" unless opened.status == 302 && request.call(:get, URI(opened["location"]).request_uri).status == 200
list = request.call(:get, "/publications/list", session)
raise "Prepared list navigation differs" unless list.status == 200 && list.body.include?(publication.title) &&
  list.body.include?('data-turbolinks="false"') && missing_title.reload.title.nil?

metadata = PdfInspector.new.call(copy.path("annotated").to_s, allow_annotated: true).metadata
paper = URI(metadata.fetch(:BaseUrl))
match = PdfRatingUrlExtractor::RATING_PATH.match(paper.path)
raise "Paper reference origin differs" unless "#{paper.scheme}://#{paper.authority}" == origin && !paper.query && !paper.fragment && match && match[1].to_i == publication.id
reference = Rack::Utils.unescape_path(match[2])
raise "Paper reference owner differs" unless PaperRatingReference.resolve(reference, publication: publication) == user
rating = request.call(:get, paper.request_uri, session)
raise "Paper rating page failed" unless rating.status == 200 && rating.body.include?('id="vote-paper-btn"')
logout = request.call(:post, "/logout.json", authorization.merge("CONTENT_TYPE" => "application/json", input: "{}"))
raise "Logout failed" unless logout.status == 200 && AuthenticationToken.count.zero?
denied = request.call(:get, "/publications.json", authorization)
raise "Logged out token is still usable" unless denied.status == 401
anonymous = request.call(:get, paper.request_uri)
raise "Paper must require login" unless anonymous.status == 200 && anonymous.body.include?('id="login-form"')
raise "Logout invalidated the paper reference" unless PaperRatingReference.resolve(reference, publication: publication) == user
raise "Logout invalidated the prepared PDF download" unless request.call(:get, URI(prepared.fetch("pdf_download_url_link")).request_uri).status == 200
raise "Unexpected acceptance data" unless Rating.count.zero? && User.count == 1 && Publication.count == 2 && missing_title.reload.title.nil?

File.open("/tmp/image-acceptance-report.json", "wx", 0o600) do |file|
  file.write(JSON.pretty_generate(
    "status" => "passed", "readiness" => true, "login_page" => true, "authentication_and_revocation" => true,
    "missing_title_presentation_without_metadata_rewrite" => true, "pdf_upload_and_annotation" => true,
    "downloads" => downloads, "open_navigation" => true, "paper_reference_and_rating_page" => true,
    "paper_reference_survives_logout" => true, "download_survives_logout" => true,
    "synthetic_users_created" => 1, "synthetic_publications_created" => 2, "ratings_submitted" => false,
    "external_http_requests" => false, "signup_and_password_reset_tested" => false, "browser_test" => false,
    "scope" => "Rack requests in a new isolated production application with a fresh database; not access to the active trial"
  ) + "\n")
end
