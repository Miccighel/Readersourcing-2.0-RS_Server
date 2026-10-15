require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../../deploy/private/recovery_configuration"

class PrivateTrialRecoveryConfigurationTest < Minitest::Test
  SOURCE_PROJECT = "rs-private-8955233c3d65"
  PROJECT = "rs-recovery-0123456789ab"
  PUBLISHED = "example.test/server@sha256:#{'1' * 64}"
  BACKUP_IMAGE = "sha256:#{'2' * 64}"
  IMAGE = "sha256:#{'3' * 64}"

  def setup
    @root = Dir.mktmpdir("rs-recovery-test.")
    @backup = File.join(@root, "backup")
    @destination = File.join(@root, "recovery")
    [@backup, @destination].each { |path| Dir.mkdir(path) }
    @original = File.join(@root, "original.json")
    @runtime = PrivateTrialRecoveryConfiguration::RUNTIME_FILES.to_h { |name| ["runtime/#{name}", "synthetic-#{name}"] }
    @configuration_files = @runtime.merge("trial.json" => JSON.generate(
      "project_name" => SOURCE_PROJECT, "files" => @runtime.transform_values { |data| Digest::SHA256.hexdigest(data) }
    ))
    @baseline = {
      "name" => SOURCE_PROJECT,
      "services" => {
        "database" => service("postgres:17", "database", "/var/lib/postgresql/data"),
        "mailpit" => {"image" => "example.test/mailpit:1", "user" => "1000:1000", "volumes" => @runtime.keys.map { |path| bind(path) }},
        "access" => {"image" => "example.test/nginx:1", "ports" => [{"published" => "33030"}]},
        "rs_server_setup" => service(PUBLISHED, "publications", "/rs_server/storage/publications/user"),
        "rs_server_webapp" => service(PUBLISHED, "publications", "/rs_server/storage/publications/user").merge(
          "environment" => {"SECRET_PROD_KEY" => "synthetic-private-secret", "PUBLIC_BASE_URL" => "http://127.0.0.1:33030"},
          "depends_on" => {"rs_server_setup" => {"condition" => "service_completed_successfully"}},
          "networks" => {"default" => nil})
      }
    }
    @baseline["services"]["rs_server_webapp"]["volumes"] << bind("runtime/smtp.crt")
    File.write(@original, JSON.generate(@baseline))
    backed_up = JSON.parse(JSON.generate(@baseline))
    %w[rs_server_setup rs_server_webapp].each { |name| backed_up["services"][name]["image"] = BACKUP_IMAGE }
    @effective = backed_up
    File.write(File.join(@backup, "effective-configuration.json"), JSON.generate(@effective))
    %w[database.dump active-images.yml database-fingerprint.jsonl publication-fingerprint.json COMPLETE].each { |name| File.write(File.join(@backup, name), "synthetic") }
    archive("configuration.tar.gz", @configuration_files)
    archive("publications.tar.gz", {"./Reader.pdf" => "%PDF-synthetic"})
    checksums
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def service(image, volume, target)
    {"image" => image, "runtime" => "runc", "read_only" => true, "mem_limit" => "1g", "cap_drop" => ["ALL"],
      "volumes" => [{"type" => "volume", "source" => volume, "target" => target}]}
  end

  def bind(path)
    {"type" => "bind", "source" => "/original/#{path}", "target" => "/trial/#{File.basename(path)}", "read_only" => true}
  end

  def archive(name, files, symlink: false)
    Zlib::GzipWriter.open(File.join(@backup, name)) do |gzip|
      Gem::Package::TarWriter.new(gzip) do |tar|
        files.each { |path, data| tar.add_file_simple(path, 0o600, data.bytesize) { |entry| entry.write(data) } }
        tar.add_symlink("unsafe-link", "/original", 0o777) if symlink
      end
    end
  end

  def checksums
    File.write(File.join(@backup, "SHA256SUMS"), PrivateTrialRecoveryConfiguration::BACKUP_FILES.map { |name|
      "#{Digest::SHA256.file(File.join(@backup, name)).hexdigest}  #{name}\n"
    }.join)
  end

  def prepare(**changes)
    PrivateTrialRecoveryConfiguration.new(**{
      backup: @backup, original: @original, destination: @destination, project: PROJECT, source_project: SOURCE_PROJECT,
      published_image: PUBLISHED, backup_image: BACKUP_IMAGE, application_image: IMAGE,
      database_image: "sha256:#{'4' * 64}", mailpit_image: "sha256:#{'5' * 64}"
    }.merge(changes)).prepare!
  end

  def test_recovery_has_new_volumes_no_access_or_setup_no_ports_and_only_internal_network
    result = prepare
    assert_equal "prepared", result["status"]
    config = JSON.parse(File.read(File.join(@destination, "compose.json")))
    assert_equal %w[database mailpit rs_server_webapp], config["services"].keys.sort
    assert_equal PROJECT, config["name"]
    assert config["networks"]["default"]["internal"]
    assert_equal "#{PROJECT}_publications", config["volumes"]["publications"]["name"]
    config["services"].each_value do |definition|
      refute definition.key?("ports")
      refute definition.key?("depends_on")
      assert_equal "never", definition["pull_policy"]
      assert_equal "no", definition["restart"]
      definition.fetch("volumes").select { |entry| entry["type"] == "bind" }.each do |entry|
        assert entry["source"].start_with?("#{@destination}/runtime/")
        assert entry["read_only"]
      end
    end
    web = config["services"]["rs_server_webapp"]
    assert_equal IMAGE, web["image"]
    assert_equal "synthetic-private-secret", web["environment"]["SECRET_PROD_KEY"]
    assert_equal "http://127.0.0.1:33030", web["environment"]["PUBLIC_BASE_URL"]
    assert_equal 0o600, File.stat(File.join(@destination, "compose.json")).mode & 0o777
    refute_includes JSON.generate(result), "synthetic-private-secret"
  end

  def test_changed_checksum_fails_before_creating_recovery_configuration
    File.write(File.join(@backup, "database.dump"), "changed")
    assert_raises(PrivateTrialRecoveryConfiguration::Error) { prepare }
    assert Dir.empty?(@destination)
  end

  def test_checksum_manifest_rejects_parent_paths_duplicates_and_omissions
    original = File.read(File.join(@backup, "SHA256SUMS"))
    [original.sub("database.dump", "../database.dump"), original + original.lines.first, original.lines.drop(1).join].each do |contents|
      File.write(File.join(@backup, "SHA256SUMS"), contents)
      assert_raises(PrivateTrialRecoveryConfiguration::Error) { prepare }
      assert Dir.empty?(@destination)
    end
  end

  def test_backup_symlink_is_rejected
    File.rename(File.join(@backup, "database.dump"), File.join(@root, "dump"))
    File.symlink(File.join(@root, "dump"), File.join(@backup, "database.dump"))
    assert_raises(PrivateTrialRecoveryConfiguration::Error) { prepare }
  end

  def test_incomplete_backup_is_rejected
    File.write(File.join(@backup, "INCOMPLETE"), "unfinished")
    assert_raises(PrivateTrialRecoveryConfiguration::Error) { prepare }
  end

  def test_unsafe_publication_archives_are_rejected_even_with_updated_checksums
    ["../outside", "/absolute"].each do |path|
      archive("publications.tar.gz", {path => "synthetic"})
      checksums
      assert_raises(PrivateTrialRecoveryConfiguration::Error) { prepare }
      assert Dir.empty?(@destination)
    end
    archive("publications.tar.gz", {}, symlink: true)
    checksums
    assert_raises(PrivateTrialRecoveryConfiguration::Error) { prepare }
    assert Dir.empty?(@destination)
  end

  def test_unsafe_configuration_archives_are_rejected
    archive("configuration.tar.gz", @configuration_files, symlink: true)
    checksums
    assert_raises(PrivateTrialRecoveryConfiguration::Error) { prepare }
  end

  def test_runtime_bytes_must_match_the_archived_trial_record
    archive("configuration.tar.gz", @configuration_files.merge("runtime/smtp.key" => "wrong"))
    checksums
    assert_raises(PrivateTrialRecoveryConfiguration::Error) { prepare }
    assert Dir.empty?(@destination)
  end

  def test_configuration_must_match_original_except_the_known_backup_image
    @effective["services"]["rs_server_webapp"]["environment"]["SECRET_PROD_KEY"] = "changed"
    File.write(File.join(@backup, "effective-configuration.json"), JSON.generate(@effective))
    checksums
    assert_raises(PrivateTrialRecoveryConfiguration::Error) { prepare }
  end

  def test_source_identity_mutable_images_and_nonempty_destination_are_rejected
    [{project: SOURCE_PROJECT}, {application_image: "server:latest"}].each do |changes|
      assert_raises(PrivateTrialRecoveryConfiguration::Error) { prepare(**changes) }
    end
    File.write(File.join(@destination, "keep"), "untouched")
    assert_raises(PrivateTrialRecoveryConfiguration::Error) { prepare }
    assert_equal "untouched", File.read(File.join(@destination, "keep"))
  end

  def test_unknown_bind_mounts_and_ports_are_rejected_even_in_a_consistent_source
    @baseline["services"]["rs_server_webapp"]["volumes"] << bind("runtime/unexpected")
    @effective["services"]["rs_server_webapp"]["volumes"] << bind("runtime/unexpected")
    File.write(@original, JSON.generate(@baseline))
    File.write(File.join(@backup, "effective-configuration.json"), JSON.generate(@effective))
    checksums
    assert_raises(PrivateTrialRecoveryConfiguration::Error) { prepare }
  end
end
