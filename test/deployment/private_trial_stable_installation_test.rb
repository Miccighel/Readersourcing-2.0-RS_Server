require "minitest/autorun"
require "tmpdir"
require "open3"
require_relative "../../deploy/private/stable_installation"

class PrivateTrialStableInstallationTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir("rs-stable-installation-test.")
    @source, @target, @definition = %w[source target definition].map { |name| File.join(@root, name) }
    [@source, @target, @definition].each { |path| Dir.mkdir(path, 0o700) }
    %w[trial activation backup].each { |name| Dir.mkdir(File.join(@source, name), 0o700) }
    @settings = {"installation_root" => "/srv/readersourcing/private-trial", "trial_directory" => "/var/tmp/rs-private.synthetic",
      "plan_directory" => "/var/tmp/rs-plan.synthetic", "lock_file" => "/var/tmp/rs-lock.synthetic/shared.lock",
      "project" => "rs-private-0123456789ab", "candidate_image" => "sha256:#{'3' * 64}", "backup_image" => "sha256:#{'2' * 64}",
      "source_revision" => 'a' * 40, "published_image" => "example.test/release@sha256:#{'1' * 64}", "override_sha256" => 'b' * 64}
    write_source("trial", "private.env", "PRIVATE=synthetic-never-print")
    Dir.mkdir(File.join(@source, "trial", "nested"), 0o700)
    write_source("trial/nested", ".hidden", "unchanged")
    %w[candidate-images.yml candidate.json startup-inventory.json].each { |name| write_source("activation", name, "retained") }
    write_source("backup", "COMPLETE", "complete")
    write_source("backup", "manifest.txt", "source_project=#{@settings.fetch('project')}\napplication_image_id=#{@settings.fetch('backup_image')}\n")
    hashes = PrivateTrialStableInstallation::BACKUP_FILES.map do |name|
      write_source("backup", name, "synthetic #{name}")
      "#{Digest::SHA256.file(File.join(@source, 'backup', name)).hexdigest}  #{name}\n"
    end
    write_source("backup", "SHA256SUMS", hashes.join)
    PrivateTrialStableInstallation::HELPERS.each { |name| File.write(File.join(@definition, name), "# retained helper\n") }
    templates = File.expand_path("../../deploy/private/stable_templates", __dir__)
    FileUtils.cp_r(templates, File.join(@definition, "stable_templates"))
  end

  def teardown
    FileUtils.remove_entry_secure(@root)
  end

  def write_source(directory, name, contents)
    File.open(File.join(@source, directory, name), "wx", 0o600) { |file| file.write(contents) }
  end

  def installer
    PrivateTrialStableInstallation.new(source: @source, destination: @target, definition: @definition, settings: @settings)
  end

  def test_copies_and_verifies_private_snapshots_without_changing_sources
    result = installer.install!
    assert_equal "stable_installation_staged", result.fetch("status")
    assert_equal %w[trial activation backup], result.fetch("snapshots_verified")
    assert_equal "PRIVATE=synthetic-never-print", File.read(File.join(@target, "configuration/trial/private.env"))
    assert_equal "unchanged", File.read(File.join(@target, "configuration/trial/nested/.hidden"))
    assert_equal "PRIVATE=synthetic-never-print", File.read(File.join(@source, "trial/private.env"))
    refute_includes JSON.generate(result), "synthetic-never-print"
    refute result.fetch("source_configuration_changed")
    refute result.fetch("containers_created_or_restarted")
    refute result.fetch("host_packages_changed")
    refute result.fetch("host_rebooted")
    refute result.fetch("recurring_backups_configured")
    refute result.fetch("automatic_startup_configured")
    assert_equal 0o600, File.stat(File.join(@target, "configuration/trial/private.env")).mode & 0o777
    assert_equal 0o700, File.stat(File.join(@target, "operations")).mode & 0o777
    assert_equal File.stat(File.join(@source, "trial")).uid, File.stat(File.join(@target, "configuration/trial")).uid
  end

  def test_rendered_wrappers_are_valid_and_pin_exact_images_and_shared_lock
    installer.install!
    operations = File.join(@target, "operations")
    %w[context.sh startup_candidate.sh restart_candidate.sh restore_rehearsal.sh].each do |name|
      _output, errors, status = Open3.capture3("sh", "-n", File.join(operations, name))
      assert status.success?, errors
    end
    context = File.read(File.join(operations, "context.sh"))
    assert_includes context, @settings.fetch("candidate_image")
    assert_includes context, @settings.fetch("backup_image")
    assert_includes context, @settings.fetch("lock_file")
    assert_includes context, "/srv/readersourcing/private-trial/configuration/backup"
    manifest = File.readlines(File.join(operations, "OPERATIONS-SHA256SUMS"))
    assert_equal 15, manifest.length
    manifest.each do |line|
      checksum, name = line.split
      assert_equal checksum, Digest::SHA256.file(File.join(operations, name)).hexdigest
    end
  end

  def test_public_helper_code_is_readable_inside_unprivileged_containers_but_host_and_secrets_remain_private
    installer.install!
    operations = File.join(@target, "operations")
    PrivateTrialStableInstallation::HELPERS.each do |name|
      assert_equal 0o644, File.stat(File.join(operations, name)).mode & 0o777
    end
    PrivateTrialStableInstallation::TEMPLATES.each do |name|
      assert_equal 0o600, File.stat(File.join(operations, name)).mode & 0o777
    end
    assert_equal 0o700, File.stat(operations).mode & 0o777
    assert_equal 0o600, File.stat(File.join(@target, "configuration/trial/private.env")).mode & 0o777
    assert_equal 0o600, File.stat(File.join(@target, "snapshots.json")).mode & 0o777
  end

  def test_read_only_snapshot_verification_rejects_changed_copies_or_sources
    installer.install!
    assert_equal "snapshots_verified", installer.verify_snapshots!.fetch("status")
    retained = File.join(@target, "configuration/trial/private.env")
    original = File.read(retained)
    File.write(retained, "changed-copy")
    assert_raises(PrivateTrialStableInstallation::Error) { installer.verify_snapshots! }
    File.write(retained, original)
    File.write(File.join(@source, "trial/private.env"), "changed-source")
    assert_raises(PrivateTrialStableInstallation::Error) { installer.verify_snapshots! }
    assert_equal original, File.read(retained)
  end

  def test_public_helper_permissions_are_explicit_even_with_a_private_process_umask
    previous = File.umask(0o077)
    installer.install!
    assert_equal 0o644, File.stat(File.join(@target, "operations/validate_trial.rb")).mode & 0o777
    assert_equal 0o600, File.stat(File.join(@target, "operations/context.sh")).mode & 0o777
  ensure
    File.umask(previous) if previous
  end

  def test_cleanup_rules_exclude_only_active_paths_and_shared_lock
    installer.install!
    rules = File.readlines(File.join(@target, "cleanup-exclusions.conf")).reject { |line| line.start_with?("#") }
    assert_equal ["x /var/tmp/rs-private.synthetic - - - - -\n", "x /var/tmp/rs-plan.synthetic - - - - -\n",
      "X /var/tmp/rs-lock.synthetic - - - - -\n", "x /var/tmp/rs-lock.synthetic/shared.lock - - - - -\n"], rules
    refute rules.any? { |line| line.include?("*") || line.split[1] == "/var/tmp" }
  end

  def test_nonempty_target_and_symlink_sources_are_rejected_without_overwriting
    File.write(File.join(@target, "retained"), "keep")
    assert_raises(PrivateTrialStableInstallation::Error) { installer.install! }
    assert_equal "keep", File.read(File.join(@target, "retained"))
    File.unlink(File.join(@target, "retained"))
    File.symlink("private.env", File.join(@source, "trial", "link"))
    assert_raises(PrivateTrialStableInstallation::Error) { installer.install! }
    assert_empty Dir.children(@target)
  end

  def test_changed_backup_and_wrong_project_are_rejected_before_copying
    File.write(File.join(@source, "backup", "database.dump"), "changed")
    assert_raises(PrivateTrialStableInstallation::Error) { installer.install! }
    assert_empty Dir.children(@target)
    @settings["project"] = "rs-private-999999999999"
    assert_raises(PrivateTrialStableInstallation::Error) { installer.install! }
  end

  def test_broad_or_interpolated_paths_are_rejected
    ["/", "/var/tmp", "/srv", "/srv/%h", "/var/tmp/*", "/srv/../srv/data", "/srv/a\nb"].each do |path|
      @settings["installation_root"] = path
      assert_raises(PrivateTrialStableInstallation::Error) { installer.install! }
      assert_empty Dir.children(@target)
    end
  end
end
