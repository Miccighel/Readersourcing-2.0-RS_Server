require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../../deploy/private/image_acceptance_diagnostic"

class ImageAcceptanceDiagnosticTest < Minitest::Test
  def test_log_classification_exports_only_fixed_categories
    value = ImageAcceptanceDiagnostic.categories("PRIVATE=never-display\nPermission denied: /private/file\nNo such image: private-name\n")
    assert_equal %w[missing_local_image permission_denied], value
    refute_includes JSON.generate(value), "never-display"
    refute_includes JSON.generate(value), "/private/file"
    refute_includes JSON.generate(value), "private-name"
  end

  def test_unknown_guard_messages_are_not_exported
    assert_equal "runtime_restrictions", ImageAcceptanceDiagnostic.guard_category("Unsafe acceptance runtime")
    assert_equal "unclassified_input_error", ImageAcceptanceDiagnostic.guard_category("private exception containing a secret")
  end

  def test_reports_only_fixed_file_presence_without_creating_files
    Dir.mktmpdir("image-diagnostic-") do |directory|
      File.write(File.join(directory, "commands.log"), "PRIVATE=never-display\n")
      before = Dir.children(directory)
      result = ImageAcceptanceDiagnostic.report(directory)
      assert_equal false, result.fetch("files_or_services_changed")
      assert_equal before, Dir.children(directory)
      assert_equal ImageAcceptanceDiagnostic::FILES.sort, result.fetch("files_present").keys.sort
      refute_includes JSON.generate(result), "never-display"
    end
  end

  def test_rejects_a_symbolic_log_link_without_reading_it
    Dir.mktmpdir("image-diagnostic-") do |directory|
      File.symlink("/unrelated/private/file", File.join(directory, "commands.log"))
      assert_raises(RuntimeError) { ImageAcceptanceDiagnostic.report(directory) }
    end
  end
end
