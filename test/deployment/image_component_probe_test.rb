require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../../deploy/private/image_component_probe"

class ImageComponentProbeTest < Minitest::Test

  def with_root
    Dir.mktmpdir("rs-image-components.") { |root| yield root }
  end

  def test_reports_only_selected_versions_and_known_components_without_reading_contents
    with_root do |root|
      path = File.join(root, "usr/bin/mount")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "synthetic-private-contents")
      output = "mount:amd64\t2.41.5-0+deb13u1\nunrelated-private-package\tsecret\n"
      result = ImageComponentProbe.new(root: root, package_output: output, mode_reader: ->(_) { 0o104755 }).report
      assert_equal({"mount" => "2.41.5-0+deb13u1"}, result["packages"])
      assert result["components"]["mount"]["present_at_checked_locations"]
      assert result["components"]["mount"]["setuid_or_setgid_at_checked_locations"]
      refute result["components"]["systemd_homed"]["present_at_checked_locations"]
      refute_includes JSON.generate(result), "synthetic-private-contents"
      refute_includes JSON.generate(result), "unrelated-private-package"
      refute_includes JSON.generate(result), root
      refute result["fresh_vulnerability_scan"]
      refute result["complete_reachability_assessment"]
      refute result["security_approval"]
    end
  end

  def test_detects_perl_archive_module_and_acl_library_without_loading_them
    with_root do |root|
      %w[usr/share/perl/5.40/Archive/Tar.pm usr/lib/x86_64-linux-gnu/libacl.so.1].each do |name|
        path = File.join(root, name)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, "not executable test content")
      end
      result = ImageComponentProbe.new(root: root, package_output: "perl-base\t5.40.1-6+deb13u1\n").report
      assert result["components"]["perl_archive_tar"]["present_at_checked_locations"]
      assert result["components"]["libacl"]["present_at_checked_locations"]
      refute result["components"]["perl_archive_tar"]["setuid_or_setgid_at_checked_locations"]
    end
  end

  def test_rejects_missing_duplicate_or_malformed_selected_package_inventory
    with_root do |root|
      ["", "private-package\tsecret\n", "mount\tprivate value\n", "mount\t1\nmount\t2\n"].each do |output|
        assert_raises(RuntimeError) { ImageComponentProbe.new(root: root, package_output: output).report }
      end
    end
  end

end
