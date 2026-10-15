require "test_helper"
require "rack/test"
require "json"

class PrivateTrialRecoveryProbeTest < ActiveSupport::TestCase
  SCRIPT = File.expand_path("../../deploy/private/recovery_probe.rb", __dir__)

  test "restored PDFs and the original paper reference work without authenticating or changing database rows" do
    Dir.mktmpdir("rs-recovery-probe.") do |directory|
      previous = ENV.to_h.slice("PUBLIC_BASE_URL", "RS_RECOVERY_PROJECT", "RS_RECOVERY_REPORT_PATH", "RS_PDF_STORAGE_ROOT")
      ENV["PUBLIC_BASE_URL"] = "http://127.0.0.1:33030"
      ENV["RS_RECOVERY_PROJECT"] = "rs-recovery-0123456789ab"
      ENV["RS_RECOVERY_REPORT_PATH"] = File.join(directory, "report.json")
      ENV["RS_PDF_STORAGE_ROOT"] = File.join(directory, "publications")
      user = User.create!(id: 3, email: "restored@rs-trial.test", password: "Synthetic-Recovery-Test!", email_confirmed: true)
      publication = Publication.create!(id: 5, pdf_url: "https://publisher.rs-trial.test/recovery.pdf")
      upload = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/Reader.pdf"), "application/pdf")
      source = PdfUpload.new(upload).fetch
      publication.fetch({host: ENV.fetch("PUBLIC_BASE_URL"), user: user}, source: source)
      before = [User, Publication, Rating, AuthenticationToken].map { |model| model.order(:id).map(&:attributes) }

      load SCRIPT

      assert_equal before, [User, Publication, Rating, AuthenticationToken].map { |model| model.order(:id).map(&:attributes) }
      report = JSON.parse(File.read(ENV.fetch("RS_RECOVERY_REPORT_PATH")))
      assert_equal "passed", report["status"]
      assert report["existing_paper_reference_verified"]
      assert report["paper_reference_requires_login"]
      assert_equal %w[annotated original], report["downloads"].keys.sort
      refute report["authentication_tokens_issued"]
      refute report["external_http_requests"]
      refute_includes File.read(ENV.fetch("RS_RECOVERY_REPORT_PATH")), "auth_token"
    ensure
      source&.close
      %w[PUBLIC_BASE_URL RS_RECOVERY_PROJECT RS_RECOVERY_REPORT_PATH RS_PDF_STORAGE_ROOT].each do |name|
        previous.key?(name) ? ENV[name] = previous.fetch(name) : ENV.delete(name)
      end
    end
  end
end
