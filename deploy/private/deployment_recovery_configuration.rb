require_relative "recovery_configuration"

class DeploymentRecoveryConfiguration < PrivateTrialRecoveryConfiguration

  BACKUP_FILES = %w[database.dump publications.tar.gz source-configuration.tar.gz new-configuration.tar.gz
    mailpit-tmp.tar.gz source-definition.json source-containers.json manifest.json runtime-files.json
    database-fingerprint.jsonl publication-fingerprint.json].freeze

  private

  def verified_configuration
    verify_layout_backup!
    manifest = JSON.parse(File.read(File.join(@backup, "manifest.json")))
    raise Error, "Backup identity differs" unless manifest.fetch("project") == @source_project &&
      manifest.fetch("application_image") == @backup_image && @images.fetch("rs_server_webapp") == @backup_image
    baseline = JSON.parse(File.read(@original))
    raise Error, "Unexpected active definition" unless baseline.fetch("name") == @source_project &&
      baseline.fetch("services").keys.sort == %w[access database mailpit rs_server_webapp]
    archived = {}
    runtime_record = JSON.parse(File.read(File.join(@backup, "runtime-files.json")))
    visit_archive("new-configuration.tar.gz") do |entry, path|
      if entry.file? && (["compose.json", "settings.json"] + RUNTIME_FILES.map { |name| "runtime/#{name}" }).include?(path)
        archived[path] = entry.read
        if path.start_with?("runtime/")
          record = runtime_record.fetch(path.delete_prefix("runtime/"))
          raise Error, "Archived runtime metadata differs" unless entry.header.uid == record.fetch("uid") &&
            entry.header.gid == record.fetch("gid") && entry.header.mode & 0o7777 == record.fetch("mode") &&
            Digest::SHA256.hexdigest(archived.fetch(path)) == record.fetch("sha256")
        end
      end
    end
    backed_up = JSON.parse(archived.fetch("compose.json"))
    raise Error, "Archived definition differs from the checked deployment" unless backed_up == baseline
    settings = JSON.parse(archived.fetch("settings.json"))
    raise Error, "Archived context differs" unless settings.fetch("project") == @source_project &&
      settings.fetch("application_image") == @backup_image && settings.fetch("source_revision") == manifest.fetch("source_revision")
    @images.each { |service, image| raise Error, "Recovery image differs from the backup" unless backed_up.fetch("services").fetch(service).fetch("image") == image }
    runtime = RUNTIME_FILES.to_h { |name| [name, archived.fetch("runtime/#{name}")] }
    visit_archive("publications.tar.gz") { |_entry, _path| }
    [backed_up, runtime]
  end

  def verify_layout_backup!
    raise Error, "Backup is incomplete" unless File.lstat(File.join(@backup, "COMPLETE")).file? && !File.exist?(File.join(@backup, "INCOMPLETE"))
    manifest = File.join(@backup, "SHA256SUMS")
    raise Error, "Expected ordinary checksum file" unless File.lstat(manifest).file?
    hashes = {}
    File.foreach(manifest) do |line|
      match = /\A([0-9a-f]{64})  ([a-zA-Z0-9.\-]+)\n?\z/.match(line)
      raise Error, "Unsafe checksum manifest" unless match && BACKUP_FILES.include?(match[2]) && !hashes.key?(match[2])
      hashes[match[2]] = match[1]
    end
    raise Error, "Incomplete checksum manifest" unless hashes.keys.sort == BACKUP_FILES.sort
    hashes.each do |name, expected|
      path = File.join(@backup, name)
      raise Error, "Backup integrity check failed" unless File.lstat(path).file? && Digest::SHA256.file(path).hexdigest == expected
    end
  end

end

if $PROGRAM_NAME == __FILE__
  begin
    raise DeploymentRecoveryConfiguration::Error, "Expected recovery options file" unless ARGV.length == 1
    options = JSON.parse(File.read(ARGV.first)).transform_keys(&:to_sym)
    puts JSON.generate(DeploymentRecoveryConfiguration.new(**options).prepare!)
  rescue StandardError => error
    warn "Deployment recovery preparation failed (#{error.class}); private values were not printed"
    exit 1
  end
end
