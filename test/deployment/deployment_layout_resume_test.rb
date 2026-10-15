require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "digest"
require "open3"

class DeploymentLayoutResumeTest < Minitest::Test
  SCRIPT = File.expand_path("../../deploy/private/deployment_layout_resume.sh", __dir__)
  FILES = %w[candidate_restart.sh candidate_startup.sh startup_inventory.rb publication_fingerprint.rb database_fingerprint.sql
    deployment_operations.sh deployment_layout_configuration.rb deployment_layout_inventory.rb deployment_layout_files.rb
    recovery_rehearsal.sh recovery_configuration.rb recovery_probe.rb candidate_configuration.rb deployment_recovery.sh
    deployment_recovery_configuration.rb OPERATIONS.md rs-server].freeze

  def with_package(mode)
    Dir.mktmpdir("rs-layout-resume-test.") do |root|
      paths = %w[original installation package work].to_h { |name| [name, File.join(root, name)] }
      paths.each_value { |path| Dir.mkdir(path) }
      FILES.each do |name|
        paths.values_at("original", "installation", "package").each { |path| File.write(File.join(path, name), "synthetic #{name}\n") }
      end
      manifest = FILES.map { |name| "#{Digest::SHA256.file(File.join(paths["original"], name)).hexdigest}  #{name}\n" }.join
      File.write(File.join(paths["original"], "ACTIVATION-SHA256SUMS"), manifest)
      File.write(File.join(paths["installation"], "OPERATIONS-SHA256SUMS"), manifest)
      File.write(File.join(paths["package"], "deployment_layout_inventory.rb"), "synthetic reviewed validator\n")
      case mode
      when "installed_change" then File.write(File.join(paths["installation"], "startup_inventory.rb"), "changed")
      when "package_change" then File.write(File.join(paths["package"], "startup_inventory.rb"), "changed")
      when "manifest_change" then File.write(File.join(paths["installation"], "OPERATIONS-SHA256SUMS"), "changed")
      when "stale_temporary" then File.write(File.join(paths["installation"], ".validator-resume"), "retained")
      when "installed_link"
        path = File.join(paths["installation"], "startup_inventory.rb")
        File.unlink(path)
        File.symlink(File.join(paths["original"], "startup_inventory.rb"), path)
      end
      anchor = Digest::SHA256.file(File.join(paths["original"], "ACTIVATION-SHA256SUMS")).hexdigest
      script = <<~SH
        set -eu
        . '#{SCRIPT}'
        rs_original_package='#{paths["original"]}'
        rs_original_package_manifest='#{anchor}'
        rs_installation_directory='#{paths["installation"]}'
        rs_package='#{paths["package"]}'
        rs_work_directory='#{paths["work"]}'
        # GNU stat ownership and root install are simulated; hashes and copies are real.
        stat() { case "$*" in */rs-server) printf '0:0:755\\n' ;; *) printf '0:0:644\\n' ;; esac; }
        install() { while [ "$#" -gt 2 ]; do shift; done; cp "$1" "$2"; }
        sha256sum() {
          if [ "$1" = --check ]; then
            shift 2
            test "$#" -ne 0 || set -- /dev/stdin
            command sha256sum -c "$@" > /dev/null
          else
            command sha256sum "$@"
          fi
        }
        layout_resume_patch_validator
      SH
      output, errors, status = Open3.capture3("sh", "-c", script)
      yield paths, output, errors, status
    end
  end

  def test_patch_changes_only_the_reviewed_validator_and_its_manifest_entry
    with_package("success") do |paths, output, errors, status|
      assert status.success?, errors
      assert_empty output
      FILES.each do |name|
        expected = name == "deployment_layout_inventory.rb" ? paths["package"] : paths["original"]
        assert_equal File.binread(File.join(expected, name)), File.binread(File.join(paths["installation"], name))
      end
      before = File.readlines(File.join(paths["work"], "operations-before.sha256"))
      after = File.readlines(File.join(paths["installation"], "OPERATIONS-SHA256SUMS"))
      assert_equal FILES, after.map { |line| line.split.last }
      assert_equal 1, before.zip(after).count { |a, b| a != b }
      assert_equal File.binread(File.join(paths["original"], "deployment_layout_inventory.rb")), File.binread(File.join(paths["work"], "validator-before.rb"))
    end
  end

  def test_drift_or_stale_output_prevents_the_validator_write
    %w[installed_change package_change manifest_change stale_temporary installed_link].each do |mode|
      with_package(mode) do |paths, _output, _errors, status|
        refute status.success?, mode
        assert_equal File.binread(File.join(paths["original"], "deployment_layout_inventory.rb")), File.binread(File.join(paths["installation"], "deployment_layout_inventory.rb"))
        refute File.exist?(File.join(paths["work"], "validator-before.rb"))
      end
    end
  end
end
