require "digest"
require "fileutils"
require "json"
require "rubygems/package"
require "zlib"
require_relative "candidate_configuration"

class PrivateTrialRecoveryConfiguration

  class Error < StandardError; end

  BACKUP_FILES = %w[database.dump publications.tar.gz configuration.tar.gz active-images.yml effective-configuration.json database-fingerprint.jsonl publication-fingerprint.json].freeze
  RUNTIME_FILES = %w[smtp.crt smtp.key smtp.auth ui.auth].freeze

  def initialize(backup:, original:, destination:, project:, source_project:, published_image:, backup_image:, application_image:, database_image:, mailpit_image:)
    @backup, @original, @destination = backup, original, destination
    @project, @source_project = project, source_project
    @published_image, @backup_image = published_image, backup_image
    @images = {"rs_server_webapp" => application_image, "database" => database_image, "mailpit" => mailpit_image}
  end

  def prepare!
    raise Error, "Invalid recovery project" unless @project.match?(/\Ars-recovery-[0-9a-f]{12}\z/)
    raise Error, "Source and recovery identities overlap" if @project == @source_project
    raise Error, "Recovery images must be exact local IDs" unless @images.values.all? { |image| image.match?(/\Asha256:[0-9a-f]{64}\z/) }
    raise Error, "Recovery destination must be empty" unless File.directory?(@destination) && !File.symlink?(@destination) && Dir.empty?(@destination)
    verify_backup!
    baseline = JSON.parse(File.read(@original))
    backed_up = JSON.parse(File.read(File.join(@backup, "effective-configuration.json")))
    PrivateTrialCandidateConfiguration.new(
      baseline: baseline, candidate: backed_up, project: @source_project,
      published_image: @published_image, candidate_image: @backup_image
    ).validate!
    runtime = {}
    visit_archive("configuration.tar.gz") do |entry, path|
      runtime[path.delete_prefix("runtime/")] = entry.read if RUNTIME_FILES.any? { |name| path == "runtime/#{name}" } && entry.file?
      if path == "trial.json" && entry.file?
        record = JSON.parse(entry.read)
        raise Error, "Wrong archived trial" unless record.fetch("project_name") == @source_project
        @archived_files = record.fetch("files")
      end
    end
    raise Error, "Missing archived runtime configuration" unless runtime.keys.sort == RUNTIME_FILES.sort && @archived_files
    runtime.each do |name, contents|
      raise Error, "Archived runtime does not match its record" unless Digest::SHA256.hexdigest(contents) == @archived_files.fetch("runtime/#{name}")
    end
    visit_archive("publications.tar.gz") { |_entry, _path| }

    FileUtils.mkdir(File.join(@destination, "runtime"), mode: 0o700)
    runtime.each { |name, contents| write("runtime/#{name}", contents) }
    services = @images.to_h do |name, image|
      service = JSON.parse(JSON.generate(backed_up.fetch("services").fetch(name)))
      service["image"] = image
      service["pull_policy"] = "never"
      service["restart"] = "no"
      service["networks"] = {"default" => nil}
      service.delete("depends_on")
      raise Error, "Unexpected published port or service identity" if %w[ports container_name network_mode build env_file devices gpus].any? { |key| service.key?(key) }
      service.fetch("volumes").each do |mount|
        case mount.fetch("type")
        when "volume"
          expected = name == "database" ? "database" : "publications"
          raise Error, "Unexpected recovery volume" unless mount.fetch("source") == expected
        when "bind"
          filename = File.basename(mount.fetch("source"))
          raise Error, "Unexpected runtime mount" unless RUNTIME_FILES.include?(filename) && mount.fetch("target") == "/trial/#{filename}" && mount.fetch("read_only")
          mount["source"] = File.join(@destination, "runtime", filename)
        else
          raise Error, "Unexpected mount type"
        end
      end
      [name, service]
    end
    definition = {
      "name" => @project, "services" => services,
      "networks" => {"default" => {"name" => "#{@project}_default", "driver" => "bridge", "internal" => true,
        "driver_opts" => {"com.docker.network.bridge.gateway_mode_ipv4" => "isolated"}}},
      "volumes" => %w[database publications].to_h { |name| [name, {"name" => "#{@project}_#{name}"}] }
    }
    write("compose.json", JSON.pretty_generate(definition) + "\n")
    {"status" => "prepared", "project" => @project, "ports_published" => false, "source_volumes_reused" => false}
  rescue KeyError, TypeError, NoMethodError, JSON::ParserError, PrivateTrialCandidateConfiguration::Error
    raise Error, "Incomplete or inconsistent recovery input"
  end

  private

  def write(relative, contents)
    File.open(File.join(@destination, relative), "wbx", 0o600) { |file| file.write(contents) }
  end

  def verify_backup!
    raise Error, "Backup is incomplete" unless File.file?(File.join(@backup, "COMPLETE")) && !File.exist?(File.join(@backup, "INCOMPLETE"))
    hashes = {}
    File.foreach(File.join(@backup, "SHA256SUMS")) do |line|
      match = /\A([0-9a-f]{64})  ([a-zA-Z0-9.\-]+)\n?\z/.match(line)
      raise Error, "Unsafe checksum manifest" unless match && BACKUP_FILES.include?(match[2]) && !hashes.key?(match[2])
      hashes[match[2]] = match[1]
    end
    raise Error, "Incomplete checksum manifest" unless hashes.keys.sort == BACKUP_FILES.sort
    hashes.each do |name, expected|
      path = File.join(@backup, name)
      raise Error, "Backup integrity check failed" unless File.file?(path) && !File.symlink?(path) && Digest::SHA256.file(path).hexdigest == expected
    end
  end

  def visit_archive(name)
    seen = {}
    Zlib::GzipReader.open(File.join(@backup, name)) do |gzip|
      Gem::Package::TarReader.new(gzip) do |tar|
        tar.each do |entry|
          raw = entry.full_name
          path = raw.delete_prefix("./").delete_suffix("/")
          raise Error, "Unsafe backup archive" if raw.start_with?("/") || raw.split("/").include?("..") || raw.include?("\0") || seen[path] || !(entry.file? || entry.directory?)
          raise Error, "Backup archive entry is too large" if entry.header.size > 100 * 1024 * 1024
          seen[path] = true
          yield entry, path
        end
      end
    end
  end

end

if $PROGRAM_NAME == __FILE__
  begin
    raise PrivateTrialRecoveryConfiguration::Error, "Expected recovery options file" unless ARGV.length == 1
    options = JSON.parse(File.read(ARGV.fetch(0))).transform_keys(&:to_sym)
    puts JSON.generate(PrivateTrialRecoveryConfiguration.new(**options).prepare!)
  rescue StandardError => error
    warn "Recovery preparation failed (#{error.class}); private values were not printed"
    exit 1
  end
end
