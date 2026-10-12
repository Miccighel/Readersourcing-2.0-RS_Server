require "minitest/autorun"
require "tmpdir"
require "yaml"
require_relative "../../deploy/private/prepare"
require_relative "../../lib/production_configuration"

class PrivateTrialTest < Minitest::Test

  def setup
    @directory = Dir.mktmpdir("rs-private-test-")
    @template = File.expand_path("../../deploy/private/compose.yml.erb", __dir__)
    @reader = File.expand_path("../fixtures/files/Reader.pdf", __dir__)
  end

  def teardown
    FileUtils.remove_entry_secure(@directory) if File.directory?(@directory)
  end

  def test_generates_a_valid_loopback_production_configuration
    prepare
    compose = configuration
    settings = environment("runtime/application.env").merge(compose.fetch("x-app").fetch("environment"))
    assert ProductionConfiguration.new(settings).validate!
    assert_equal "http://127.0.0.1:33030", settings.fetch("PUBLIC_BASE_URL")
    assert_equal "false", settings.fetch("RS_PDF_ALLOW_PRIVATE_NETWORKS")
    assert_equal "false", settings.fetch("FORCE_SSL")
  end

  def test_publishes_only_the_two_loopback_ports_and_uses_an_internal_network
    prepare
    compose = configuration
    assert_equal true, compose.fetch("networks").fetch("default").fetch("internal")
    services = compose.fetch("services")
    ports = services.values.flat_map { |service| service.fetch("ports", []) }
    assert_equal ["127.0.0.1:33030:3000", "127.0.0.1:33031:8025"], ports.sort
    services.each_value do |service|
      refute service.key?("build")
      refute service.key?("network_mode")
      refute service.fetch("privileged", false)
      assert_equal "no", service.fetch("restart")
      assert service.key?("cpus")
      assert service.key?("mem_limit")
    end
    assert_equal PrivateTrial::APPLICATION_IMAGE, services.fetch("rs_server_webapp").fetch("image")
  end

  def test_keeps_the_database_and_mail_environment_separate_from_the_signing_secret
    prepare
    assert_equal %w[POSTGRES_DB POSTGRES_PASSWORD POSTGRES_USER], environment("runtime/database.env").keys.sort
    mail = environment("runtime/mailpit.env")
    assert_equal "true", mail.fetch("MP_SMTP_REQUIRE_STARTTLS")
    assert_equal "/trial/smtp.auth", mail.fetch("MP_SMTP_AUTH_FILE")
    assert_equal "/trial/ui.auth", mail.fetch("MP_UI_AUTH_FILE")
    refute mail.key?("MP_SMTP_AUTH_ACCEPT_ANY")
    refute mail.keys.any? { |name| name.include?("RELAY") || name.include?("FORWARD") }
    refute mail.key?("SECRET_PROD_KEY")
    smtp_auth = File.read(File.join(@directory, "runtime/smtp.auth")).strip
    assert_equal "rs-trial:#{environment("runtime/application.env").fetch("SMTP_PASSWORD")}", smtp_auth
  end

  def test_protects_credentials_and_keeps_the_reader_fixture_unchanged
    prepare
    assert_equal 0o700, File.stat(@directory).mode & 0o777
    %w[application.env database.env mailpit.env smtp.key smtp.auth ui.auth].each do |name|
      assert_equal 0o600, File.stat(File.join(@directory, "runtime", name)).mode & 0o777
    end
    assert_equal PrivateTrial::READER_SHA256, Digest::SHA256.file(File.join(@directory, "fixtures/Reader.pdf")).hexdigest
    assert_equal "rs-trial", File.read(File.join(@directory, "runtime/ui.auth")).split(":").first
  end

  def test_certificate_is_valid_for_mailpit_and_matches_the_private_key
    prepare
    certificate = OpenSSL::X509::Certificate.new(File.read(File.join(@directory, "runtime/smtp.crt")))
    key = OpenSSL::PKey.read(File.read(File.join(@directory, "runtime/smtp.key")))
    assert certificate.check_private_key(key)
    assert OpenSSL::SSL.verify_certificate_identity(certificate, "mailpit")
    refute OpenSSL::SSL.verify_certificate_identity(certificate, "another-host")
    store = OpenSSL::X509::Store.new
    store.add_cert(certificate)
    assert store.verify(certificate)
    assert_operator certificate.not_after, :>, Time.now
  end

  def test_project_and_configuration_record_validate_without_exposing_secrets
    project = prepare
    assert_match(/\Ars-private-[0-9a-f]{12}\z/, project)
    assert_equal project, PrivateTrial.validate!(@directory)
    record_text = File.read(File.join(@directory, "trial.json"))
    settings = environment("runtime/application.env")
    refute_includes record_text, settings.fetch("SECRET_PROD_KEY")
    refute_includes record_text, settings.fetch("POSTGRES_PASSWORD")
    refute_includes record_text, settings.fetch("SMTP_PASSWORD")
  end

  def test_refuses_to_overwrite_an_existing_directory
    filename = File.join(@directory, "existing.txt")
    File.write(filename, "preserve this")
    assert_raises(RuntimeError) { prepare }
    assert_equal "preserve this", File.read(filename)
    assert_equal ["existing.txt"], Dir.children(@directory)
  end

  def test_refuses_a_different_pdf_fixture_before_writing_configuration
    alternate = File.join(@directory, "different.pdf")
    File.write(alternate, "not the fixture")
    empty = Dir.mktmpdir("empty-", @directory)
    assert_raises(RuntimeError) { PrivateTrial.new(directory: empty, template: @template, reader: alternate).prepare! }
    assert_empty Dir.children(empty)
  end

  def test_refuses_a_symbolic_link_as_the_trial_directory
    actual = Dir.mktmpdir("actual-", @directory)
    link = File.join(@directory, "linked")
    File.symlink(actual, link)
    assert_raises(RuntimeError) { PrivateTrial.new(directory: link, template: @template, reader: @reader).prepare! }
    assert_empty Dir.children(actual)
  end

  def test_rejects_changed_configuration_and_project_identity
    prepare
    File.open(File.join(@directory, "compose.yml"), "a") { |file| file.write("\n# changed\n") }
    assert_raises(RuntimeError) { PrivateTrial.validate!(@directory) }
  end

  def test_requires_the_complete_configuration_record
    prepare
    record_path = File.join(@directory, "trial.json")
    record = JSON.parse(File.read(record_path))
    record.fetch("files").delete("compose.yml")
    File.write(record_path, JSON.generate(record))
    assert_raises(RuntimeError) { PrivateTrial.validate!(@directory) }
  end

  private

  def prepare
    PrivateTrial.new(directory: @directory, template: @template, reader: @reader).prepare!
  end

  def configuration
    YAML.safe_load_file(File.join(@directory, "compose.yml"), aliases: true)
  end

  def environment(relative)
    File.readlines(File.join(@directory, relative), chomp: true).to_h { |line| line.split("=", 2) }
  end
end
