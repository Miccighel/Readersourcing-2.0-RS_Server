require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../../deploy/private/deployment_recovery_configuration"
require_relative "../../deploy/private/deployment_layout_files"

class DeploymentRecoveryConfigurationTest < Minitest::Test
  SOURCE = "rs-private-0123456789ab"
  TARGET = "rs-recovery-0123456789ab"
  IMAGES = {"database" => "sha256:#{'1' * 64}", "mailpit" => "sha256:#{'2' * 64}", "rs_server_webapp" => "sha256:#{'3' * 64}"}.freeze

  def setup
    @root = Dir.mktmpdir("rs-layout-recovery-test.")
    @backup, @destination = File.join(@root, "backup"), File.join(@root, "recovery")
    Dir.mkdir(@backup)
    Dir.mkdir(@destination)
    @original = File.join(@root, "original.json")
    @runtime = %w[smtp.crt smtp.key smtp.auth ui.auth proxy.conf].to_h { |name| ["runtime/#{name}", "synthetic-#{name}"] }
    @record = @runtime.to_h { |path, bytes| [File.basename(path), {"sha256" => Digest::SHA256.hexdigest(bytes), "uid" => 0, "gid" => 0, "mode" => 0o600}] }
    @definition = {"name" => SOURCE, "services" => {"access" => {"ports" => [{"published" => "33030"}]}}}
    IMAGES.each do |service, image|
      mounts = []
      mounts << {"type" => "volume", "source" => service == "database" ? "database" : "publications", "target" => "/data"} unless service == "mailpit"
      files = service == "mailpit" ? %w[smtp.crt smtp.key smtp.auth ui.auth] : (service == "rs_server_webapp" ? ["smtp.crt"] : [])
      files.each { |name| mounts << {"type" => "bind", "source" => "/etc/opt/readersourcing/rs-server/runtime/#{name}", "target" => "/trial/#{name}", "read_only" => true} }
      @definition["services"][service] = {"image" => image, "runtime" => "runc", "read_only" => true,
        "environment" => {"PRIVATE" => "synthetic-secret", "PUBLIC_BASE_URL" => "http://127.0.0.1:33030"}, "volumes" => mounts,
        "networks" => {"default" => nil}, "depends_on" => {"database" => {"condition" => "service_healthy"}}}
    end
    @settings = {"project" => SOURCE, "application_image" => IMAGES["rs_server_webapp"], "source_revision" => "f" * 40}
    @manifest = {"project" => SOURCE, "application_image" => IMAGES["rs_server_webapp"], "source_revision" => "f" * 40}
    File.write(@original, JSON.generate(@definition))
    DeploymentRecoveryConfiguration::BACKUP_FILES.each { |name| File.write(File.join(@backup, name), "synthetic") }
    File.write(File.join(@backup, "COMPLETE"), "verified")
    rebuild
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def archive(name, files, symlink: false)
    Zlib::GzipWriter.open(File.join(@backup, name)) do |gzip|
      Gem::Package::TarWriter.new(gzip) do |tar|
        files.each { |path, bytes| tar.add_file_simple(path, 0o600, bytes.bytesize) { |entry| entry.write(bytes) } }
        tar.add_symlink("unexpected", "/private", 0o777) if symlink
      end
    end
  end

  def checksums
    File.write(File.join(@backup, "SHA256SUMS"), DeploymentRecoveryConfiguration::BACKUP_FILES.map { |name|
      "#{Digest::SHA256.file(File.join(@backup, name)).hexdigest}  #{name}\n"
    }.join)
  end

  def rebuild
    archive("new-configuration.tar.gz", @runtime.merge("compose.json" => JSON.generate(@definition), "settings.json" => JSON.generate(@settings)))
    archive("publications.tar.gz", {"./Reader.pdf" => "%PDF-synthetic"})
    File.write(File.join(@backup, "runtime-files.json"), JSON.generate(@record))
    File.write(File.join(@backup, "manifest.json"), JSON.generate(@manifest))
    checksums
  end

  def prepare(**changes)
    DeploymentRecoveryConfiguration.new(**{backup: @backup, original: @original, destination: @destination,
      project: TARGET, source_project: SOURCE, published_image: "", backup_image: IMAGES["rs_server_webapp"],
      application_image: IMAGES["rs_server_webapp"], database_image: IMAGES["database"], mailpit_image: IMAGES["mailpit"]}.merge(changes)).prepare!
  end

  def test_layout_backup_restores_only_into_new_isolated_volumes_and_preserves_the_application_context
    result = prepare
    assert_equal "prepared", result["status"]
    config = JSON.parse(File.read(File.join(@destination, "compose.json")))
    assert_equal %w[database mailpit rs_server_webapp], config["services"].keys.sort
    assert_equal TARGET, config["name"]
    assert config["networks"]["default"]["internal"]
    assert_equal "#{TARGET}_database", config["volumes"]["database"]["name"]
    assert_equal "#{TARGET}_publications", config["volumes"]["publications"]["name"]
    config["services"].each do |name, service|
      assert_equal IMAGES.fetch(name), service["image"]
      assert_equal "never", service["pull_policy"]
      assert_equal "no", service["restart"]
      refute service.key?("ports")
      refute service.key?("depends_on")
      service["volumes"].select { |mount| mount["type"] == "bind" }.each { |mount| assert mount["source"].start_with?("#{@destination}/runtime/"); assert mount["read_only"] }
    end
    assert_equal "synthetic-secret", config["services"]["rs_server_webapp"]["environment"]["PRIVATE"]
    assert_equal "http://127.0.0.1:33030", config["services"]["rs_server_webapp"]["environment"]["PUBLIC_BASE_URL"]
    refute_includes JSON.generate(result), "synthetic-secret"
  end

  def test_migration_validates_the_actual_backup_definition_before_creating_replacement_services
    paths = %i[definition plan source checks configuration state].to_h { |name| [name, File.join(@root, name.to_s)] }
    paths.each_value { |path| Dir.mkdir(path) }
    File.write(File.join(paths[:definition], "settings.json"), JSON.generate(@settings))
    File.write(File.join(paths[:state], "definition.json"), JSON.generate(@definition))
    File.write(File.join(paths[:checks], "effective.json"), JSON.generate(@definition))
    checker = DeploymentLayoutFiles.new(**paths, backup: @backup)
    assert_equal "layout_recovery_code_loaded", checker.perform("recovery-code")["status"]
    report = checker.perform("recovery-preflight")
    assert_equal "layout_backup_recovery_definition_verified", report["status"]
    refute report["recovery_containers_created"]
    assert File.file?(File.join(paths[:checks], "recovery-preflight", "compose.json"))
    assert Dir.empty?(paths[:configuration])
    assert Dir.empty?(@destination)
  end

  def test_changed_archive_manifest_definition_and_runtime_metadata_are_rejected_before_writes
    [
      -> { File.write(File.join(@backup, "database.dump"), "changed") },
      -> { @manifest["project"] = "another"; rebuild },
      -> { @settings["source_revision"] = "changed"; rebuild },
      -> { @record["smtp.key"]["mode"] = 0o644; rebuild },
      -> { @record["smtp.key"]["sha256"] = "0" * 64; rebuild },
      -> { File.write(@original, "{}") },
      -> { File.write(File.join(@backup, "INCOMPLETE"), "unfinished") }
    ].each_with_index do |change, index|
      teardown if index > 0
      setup if index > 0
      change.call
      assert_raises(DeploymentRecoveryConfiguration::Error) { prepare }
      assert Dir.empty?(@destination)
    end
  end

  def test_checksums_reject_parent_paths_duplicates_omissions_and_symbolic_links
    text = File.read(File.join(@backup, "SHA256SUMS"))
    [text.sub("database.dump", "../database.dump"), text + text.lines.first, text.lines.drop(1).join].each do |bad|
      File.write(File.join(@backup, "SHA256SUMS"), bad)
      assert_raises(DeploymentRecoveryConfiguration::Error) { prepare }
      assert Dir.empty?(@destination)
    end
    checksums
    dump = File.join(@backup, "database.dump")
    File.rename(dump, "#{dump}.retained")
    File.symlink("#{dump}.retained", dump)
    assert_raises(DeploymentRecoveryConfiguration::Error) { prepare }
  end

  def test_unsafe_archives_foreign_or_shared_recovery_identity_and_changed_images_are_rejected
    [{project: SOURCE}, {project: "unrelated"}, {database_image: "sha256:#{'9' * 64}"}, {application_image: "mutable-tag"}].each do |options|
      assert_raises(DeploymentRecoveryConfiguration::Error) { prepare(**options) }
      assert Dir.empty?(@destination)
    end
    archive("publications.tar.gz", {"../Reader.pdf" => "bad"})
    checksums
    assert_raises(DeploymentRecoveryConfiguration::Error) { prepare }
    assert Dir.empty?(@destination)
  end
end
