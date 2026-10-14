require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../../deploy/private/publication_fingerprint"

class PrivatePublicationFingerprintTest < Minitest::Test

  def setup
    @directory = Dir.mktmpdir("rs-publication-fingerprint.")
    File.binwrite(File.join(@directory, "original.pdf"), "synthetic PDF bytes")
    File.binwrite(File.join(@directory, ".copy-state.json"), "synthetic control data")
    Dir.mkdir(File.join(@directory, "empty"))
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def fingerprint
    PrivatePublicationFingerprint.new(@directory).calculate
  end

  def test_includes_hidden_files_and_empty_directories_without_exposing_paths
    result = fingerprint
    assert_equal 2, result.fetch("files")
    assert_equal 2, result.fetch("directories")
    refute_includes JSON.generate(result), "original.pdf"
    refute_includes JSON.generate(result), "synthetic control data"
    assert_equal result, fingerprint
  end

  def test_ignores_timestamps_but_detects_content_and_permission_changes
    original = fingerprint
    path = File.join(@directory, "original.pdf")
    File.utime(Time.at(1), Time.at(1), path)
    assert_equal original, fingerprint
    File.binwrite(path, "different PDF bytes")
    refute_equal original.fetch("sha256"), fingerprint.fetch("sha256")
    changed = fingerprint
    File.chmod(0o600, path)
    refute_equal changed.fetch("sha256"), fingerprint.fetch("sha256")
  end

  def test_detects_an_added_empty_directory
    original = fingerprint
    Dir.mkdir(File.join(@directory, "another"))
    refute_equal original.fetch("sha256"), fingerprint.fetch("sha256")
  end

  def test_rejects_symlinks_without_reading_the_target
    File.symlink("original.pdf", File.join(@directory, "link.pdf"))
    assert_raises(PrivatePublicationFingerprint::Error) { fingerprint }
  end

end
