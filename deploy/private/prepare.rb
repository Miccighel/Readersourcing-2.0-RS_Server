require "digest"
require "erb"
require "fileutils"
require "json"
require "openssl"
require "securerandom"

class PrivateTrial

  APPLICATION_IMAGE = "miccighel/rs_server@sha256:d35ad4383b7bf9a530390ade8e0b5dee1535d3933eb27174207b242028b38303".freeze
  READER_SHA256 = "0804774bb87edd869a95141f00bc6c3559e4b6df3b7b94412c10c9a7f6e8dfab".freeze

  def initialize(directory:, template:, reader:)
    @directory = File.expand_path(directory)
    @template = template
    @reader = reader
  end

  def prepare!
    raise "The trial requires an existing empty directory" unless File.directory?(@directory) && Dir.children(@directory).empty?
    raise "The trial directory must not be a symbolic link" if File.symlink?(@directory)
    @directory = File.realpath(@directory)
    raise "The fixture differs from the retained Reader.pdf" unless Digest::SHA256.file(@reader).hexdigest == READER_SHA256

    File.chmod(0o700, @directory)
    @files = []
    @project_name = "rs-private-#{SecureRandom.hex(6)}"
    stat = File.stat(@directory)
    @uid, @gid = stat.uid, stat.gid
    FileUtils.mkdir(File.join(@directory, "runtime"), mode: 0o700)
    FileUtils.mkdir(File.join(@directory, "fixtures"), mode: 0o700)

    database_password = SecureRandom.hex(32)
    smtp_password = SecureRandom.hex(32)
    ui_password = SecureRandom.hex(32)
    certificate, key = smtp_certificate
    write("runtime/smtp.crt", certificate.to_pem, mode: 0o644)
    write("runtime/smtp.key", key.to_pem)
    write("runtime/smtp.auth", "rs-trial:#{smtp_password}\n")
    write("runtime/ui.auth", "rs-trial:#{ui_password}\n")

    database = {"POSTGRES_USER" => "rs_trial", "POSTGRES_PASSWORD" => database_password, "POSTGRES_DB" => "rs_trial"}
    application = database.merge(
      "SECRET_PROD_KEY" => SecureRandom.hex(64),
      "SMTP_USERNAME" => "rs-trial", "SMTP_PASSWORD" => smtp_password,
      "SMTP_DOMAIN_NAME" => "rs-trial.test", "SMTP_PORT" => "1025", "SMTP_AUTHENTICATION" => "plain",
      "SMTP_OPEN_TIMEOUT" => "5", "SMTP_READ_TIMEOUT" => "10",
      "EMAIL_ADMIN" => "admin@rs-trial.test", "EMAIL_BUG_REPORT" => "bugs@rs-trial.test",
      "PRIVACY_CONTROLLER_NAME" => "Private validation operator",
      "PRIVACY_HOSTING_PROVIDER" => "Private trial host", "PRIVACY_HOSTING_COUNTRY" => "Italy",
      "PRIVACY_EMAIL_PROVIDER" => "Local Mailpit capture", "PRIVACY_EMAIL_PROVIDER_COUNTRY" => "Italy",
      "PRIVACY_LOG_RETENTION_DAYS" => "1", "PRIVACY_BACKUP_RETENTION_DAYS" => "1",
      "RAILS_LOG_TO_STDOUT" => "1", "RAILS_MAX_THREADS" => "5"
    )
    mailpit = {
      "MP_DATABASE" => "/tmp/mailpit.db", "MP_MAX_MESSAGES" => "100",
      "MP_SMTP_TLS_CERT" => "/trial/smtp.crt", "MP_SMTP_TLS_KEY" => "/trial/smtp.key",
      "MP_SMTP_REQUIRE_STARTTLS" => "true", "MP_SMTP_AUTH_FILE" => "/trial/smtp.auth",
      "MP_UI_AUTH_FILE" => "/trial/ui.auth", "MP_ALLOWED_HOSTS" => "127.0.0.1,localhost,mailpit"
    }
    write_env("runtime/database.env", database)
    write_env("runtime/application.env", application)
    write_env("runtime/mailpit.env", mailpit)
    write("runtime/proxy.conf", File.binread(File.join(File.dirname(@template), "proxy.conf")))
    write("fixtures/Reader.pdf", File.binread(@reader))
    write("compose.yml", ERB.new(File.read(@template)).result(binding))
    write("project-name", "#{@project_name}\n")
    record = {
      "schema_version" => 1, "project_name" => @project_name,
      "application_image" => APPLICATION_IMAGE, "created_at" => Time.now.utc.strftime("%FT%TZ"),
      "smtp_certificate_expires_at" => certificate.not_after.utc.strftime("%FT%TZ"),
      "files" => @files.to_h { |relative| [relative, Digest::SHA256.file(File.join(@directory, relative)).hexdigest] }
    }
    write("trial.json", JSON.pretty_generate(record) + "\n")
    @project_name
  end

  def self.validate!(directory)
    record = JSON.parse(File.read(File.join(directory, "trial.json")))
    project_name = record.fetch("project_name")
    raise "Invalid private trial project" unless project_name.match?(/\Ars-private-[0-9a-f]{12}\z/)
    raise "Unexpected application image" unless record.fetch("application_image") == APPLICATION_IMAGE
    required = %w[compose.yml project-name runtime/database.env runtime/application.env runtime/mailpit.env runtime/proxy.conf runtime/smtp.crt runtime/smtp.key runtime/smtp.auth runtime/ui.auth fixtures/Reader.pdf]
    raise "Incomplete private trial record" unless record.fetch("files").keys.sort == required.sort
    record.fetch("files").each do |relative, expected|
      filename = File.join(directory, relative)
      raise "A generated trial file was changed" if File.symlink?(filename) || Digest::SHA256.file(filename).hexdigest != expected
    end
    raise "The project identity was changed" unless File.read(File.join(directory, "project-name")).strip == project_name
    project_name
  end

  private

  def project_name = @project_name
  def application_image = APPLICATION_IMAGE
  def uid = @uid
  def gid = @gid

  def write(relative, contents, mode: 0o600)
    File.open(File.join(@directory, relative), "wbx", mode) { |file| file.write(contents) }
    @files << relative
  end

  def write_env(relative, settings)
    write(relative, settings.map { |name, value| "#{name}=#{value}\n" }.join)
  end

  def smtp_certificate
    key = OpenSSL::PKey::RSA.new(2048)
    certificate = OpenSSL::X509::Certificate.new
    certificate.version = 2
    certificate.serial = SecureRandom.random_number(2**128)
    certificate.subject = OpenSSL::X509::Name.parse("/CN=mailpit")
    certificate.issuer = certificate.subject
    certificate.public_key = key.public_key
    certificate.not_before = Time.now - 60
    certificate.not_after = Time.now + 30 * 24 * 60 * 60
    extensions = OpenSSL::X509::ExtensionFactory.new
    extensions.subject_certificate = certificate
    extensions.issuer_certificate = certificate
    certificate.add_extension(extensions.create_extension("basicConstraints", "CA:TRUE", true))
    certificate.add_extension(extensions.create_extension("keyUsage", "digitalSignature,keyEncipherment,keyCertSign", true))
    certificate.add_extension(extensions.create_extension("extendedKeyUsage", "serverAuth"))
    certificate.add_extension(extensions.create_extension("subjectAltName", "DNS:mailpit"))
    certificate.sign(key, OpenSSL::Digest.new("SHA256"))
    [certificate, key]
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.first == "validate"
    abort "Usage: prepare.rb validate DIRECTORY" unless ARGV.length == 2
    puts PrivateTrial.validate!(ARGV.fetch(1))
  else
    abort "Usage: prepare.rb DIRECTORY TEMPLATE READER" unless ARGV.length == 3
    project = PrivateTrial.new(directory: ARGV[0], template: ARGV[1], reader: ARGV[2]).prepare!
    puts "Private trial prepared: #{project}. Credentials remain in the private runtime directory."
  end
end
