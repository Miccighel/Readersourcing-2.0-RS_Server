require "digest"
require "erb"
require "fileutils"
require "json"
require "shellwords"

class PrivateTrialStableInstallation

  class Error < StandardError; end
  HELPERS = %w[candidate_restart.sh candidate_startup.sh startup_inventory.rb restart_configuration.rb
    candidate_configuration.rb validate_trial.rb publication_fingerprint.rb database_fingerprint.sql
    recovery_rehearsal.sh recovery_configuration.rb recovery_probe.rb].freeze
  TEMPLATES = %w[context.sh startup_candidate.sh restart_candidate.sh restore_rehearsal.sh].freeze
  BACKUP_FILES = %w[database.dump publications.tar.gz configuration.tar.gz active-images.yml
    effective-configuration.json database-fingerprint.jsonl publication-fingerprint.json].freeze

  def initialize(source:, destination:, definition:, settings:)
    @source, @destination, @definition, @settings = source, destination, definition, settings
  end

  def install!
    raise Error, "Destination must be an empty ordinary directory" unless File.directory?(@destination) && !File.symlink?(@destination) && Dir.empty?(@destination)
    validate_settings!
    verify_backup!
    %w[candidate-images.yml candidate.json startup-inventory.json].each do |name|
      regular_file!(File.join(@source, "activation", name))
    end
    snapshots = %w[trial activation backup].to_h do |name|
      from, to = File.join(@source, name), File.join(@destination, "configuration", name)
      before = inventory(from)
      FileUtils.mkdir_p(File.dirname(to), mode: 0o700)
      copy_tree(from, to)
      raise Error, "Snapshot differs from its source" unless inventory(to) == before && inventory(from) == before
      [name, before]
    end
    operations = File.join(@destination, "operations")
    Dir.mkdir(operations, 0o700)
    HELPERS.each do |name|
      path = File.join(@definition, name)
      regular_file!(path)
      # Some helpers run as the existing unprivileged container users. Their code is public;
      # host access remains restricted by the root owned operations directory.
      write(File.join(operations, name), File.binread(path), mode: 0o644)
    end
    TEMPLATES.each do |name|
      path = File.join(@definition, "stable_templates", "#{name}.erb")
      regular_file!(path)
      write(File.join(operations, name), ERB.new(File.read(path), trim_mode: "-").result(binding))
    end
    guide = File.join(@definition, "stable_templates", "OPERATIONS.md")
    regular_file!(guide)
    write(File.join(@destination, "OPERATIONS.md"), File.binread(guide))
    files = HELPERS + TEMPLATES
    manifest = files.sort.map { |name| "#{Digest::SHA256.file(File.join(operations, name)).hexdigest}  #{name}\n" }.join
    write(File.join(operations, "OPERATIONS-SHA256SUMS"), manifest)
    write(File.join(@destination, "snapshots.json"), JSON.pretty_generate(snapshots) + "\n")
    write(File.join(@destination, "cleanup-exclusions.conf"), cleanup_rules)
    result = {"status" => "stable_installation_staged", "project" => @settings.fetch("project"),
      "candidate_image" => @settings.fetch("candidate_image"), "snapshots_verified" => snapshots.keys,
      "snapshot_files_checked" => snapshots.values.sum { |entries| entries.count { |entry| entry.fetch("type") == "file" } },
      "source_configuration_changed" => false, "active_paths_relocated" => false,
      "containers_created_or_restarted" => false, "automatic_startup_configured" => false,
      "recurring_backups_configured" => false, "host_packages_changed" => false, "host_rebooted" => false}
    write(File.join(@destination, "installation.json"), JSON.pretty_generate(result) + "\n")
    result
  end

  def verify_snapshots!
    record = File.join(@destination, "snapshots.json")
    regular_file!(record)
    snapshots = JSON.parse(File.read(record))
    raise Error, "Unexpected snapshot record" unless snapshots.keys.sort == %w[activation backup trial]
    snapshots.each do |name, expected|
      raise Error, "Retained snapshot differs" unless inventory(File.join(@destination, "configuration", name)) == expected
      raise Error, "Source configuration differs" unless inventory(File.join(@source, name)) == expected
    end
    {"status" => "snapshots_verified", "source_and_retained_configuration_match" => true}
  end

  private

  def validate_settings!
    expected = %w[installation_root trial_directory plan_directory lock_file project candidate_image backup_image source_revision published_image override_sha256]
    raise Error, "Unexpected installation settings" unless @settings.keys.sort == expected.sort
    %w[installation_root trial_directory plan_directory lock_file].each do |name|
      path = @settings.fetch(name)
      raise Error, "Invalid operation path" unless path.is_a?(String) && path.match?(/\A\/[A-Za-z0-9_.\/-]+\z/) && File.expand_path(path) == path && !%w[/ /srv /var /var/tmp /tmp].include?(path)
    end
    raise Error, "Invalid project" unless @settings.fetch("project").match?(/\Ars-private-[0-9a-f]{12}\z/)
    raise Error, "Invalid image" unless @settings.fetch("candidate_image").match?(/\Asha256:[0-9a-f]{64}\z/)
    raise Error, "Invalid backup image" unless @settings.fetch("backup_image").match?(/\Asha256:[0-9a-f]{64}\z/)
    raise Error, "Invalid release image" unless @settings.fetch("published_image").match?(/\A[^\s]+@sha256:[0-9a-f]{64}\z/)
    raise Error, "Invalid source revision" unless @settings.fetch("source_revision").match?(/\A[0-9a-f]{40}\z/)
    raise Error, "Invalid override hash" unless @settings.fetch("override_sha256").match?(/\A[0-9a-f]{64}\z/)
  end

  def regular_file!(path)
    raise Error, "Expected an ordinary file" unless File.lstat(path).file?
  end

  def verify_backup!
    directory = File.join(@source, "backup")
    regular_file!(File.join(directory, "COMPLETE"))
    identity = File.join(directory, "manifest.txt")
    regular_file!(identity)
    lines = File.readlines(identity, chomp: true)
    raise Error, "Unexpected backup identity" unless lines.include?("source_project=#{@settings.fetch('project')}") && lines.include?("application_image_id=#{@settings.fetch('backup_image')}")
    raise Error, "Incomplete source backup" if File.exist?(File.join(directory, "INCOMPLETE"))
    manifest = File.join(directory, "SHA256SUMS")
    regular_file!(manifest)
    hashes = {}
    File.foreach(manifest) do |line|
      match = /\A([0-9a-f]{64})  ([a-zA-Z0-9.\-]+)\n?\z/.match(line)
      raise Error, "Invalid backup checksum record" unless match && BACKUP_FILES.include?(match[2]) && !hashes.key?(match[2])
      hashes[match[2]] = match[1]
    end
    raise Error, "Incomplete backup checksum record" unless hashes.keys.sort == BACKUP_FILES.sort
    hashes.each do |name, checksum|
      path = File.join(directory, name)
      regular_file!(path)
      raise Error, "Backup checksum mismatch" unless Digest::SHA256.file(path).hexdigest == checksum
    end
  end

  def inventory(directory)
    entries = []
    visit = lambda do |path, relative|
      info = File.lstat(path)
      raise Error, "Unsupported snapshot entry" unless info.directory? || info.file?
      entry = {"path" => relative, "type" => info.directory? ? "directory" : "file",
        "uid" => info.uid, "gid" => info.gid, "mode" => info.mode & 0o7777}
      entry["sha256"] = Digest::SHA256.file(path).hexdigest if info.file?
      entries << entry
      Dir.children(path).sort.each { |name| visit.call(File.join(path, name), "#{relative}/#{name}") } if info.directory?
    end
    raise Error, "Expected a snapshot directory" unless File.lstat(directory).directory?
    visit.call(directory, ".")
    entries
  end

  def copy_tree(source, target)
    info = File.lstat(source)
    if info.directory?
      Dir.mkdir(target, 0o700)
      Dir.children(source).sort.each { |name| copy_tree(File.join(source, name), File.join(target, name)) }
    elsif info.file?
      File.open(source, File::RDONLY | File::NOFOLLOW) do |input|
        File.open(target, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |output| IO.copy_stream(input, output) }
      end
    else
      raise Error, "Unsupported snapshot entry"
    end
    File.chown(info.uid, info.gid, target)
    File.chmod(info.mode & 0o7777, target)
  end

  def write(path, contents, mode: 0o600)
    File.open(path, "wx", mode) { |file| file.write(contents) }
    File.chmod(mode, path)
  end

  def shell(name) = Shellwords.escape(@settings.fetch(name))

  def cleanup_rules
    trial, plan, lock = @settings.values_at("trial_directory", "plan_directory", "lock_file")
    "# Only the active Readersourcing trial and its shared lock are excluded from age based cleanup.\n" +
      ["x #{trial}", "x #{plan}", "X #{File.dirname(lock)}", "x #{lock}"].map { |entry| "#{entry} - - - - -\n" }.join
  end

end

if $PROGRAM_NAME == __FILE__
  begin
    raise PrivateTrialStableInstallation::Error, "Root permission is required" unless Process.uid == 0
    raise PrivateTrialStableInstallation::Error, "Expected public installation settings" unless ARGV.length == 1
    result = PrivateTrialStableInstallation.new(source: "/source", destination: "/installation", definition: "/definition",
      settings: JSON.parse(File.read(ARGV.fetch(0)))).install!
    puts JSON.pretty_generate(result)
  rescue StandardError => error
    warn "Stable installation failed (#{error.class}); private values were not printed"
    exit 1
  end
end
