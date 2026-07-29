require "test_helper"
require "rbconfig"
require "tmpdir"

class RsPdfRunnerTest < ActiveSupport::TestCase

  test "passes every value as a process argument without shell interpolation" do
    Dir.mktmpdir("rs_pdf_runner_test") do |directory|
      expected_output = File.join(directory, "Reader-Link.pdf")
      script = <<~'RUBY'
        output_index = ARGV.index("-pOut")
        File.write(File.join(ARGV.fetch(output_index + 1), "Reader-Link.pdf"), "%PDF")
      RUBY
      marker = File.join(directory, "must-not-exist")
      runner = RsPdfRunner.new(
        jar_path: "unused",
        command_prefix: [RbConfig.ruby, "-e", script, "--"]
      )

      result = runner.call(
        input_path: File.join(directory, "Reader;touch must-not-exist.pdf"),
        output_path: directory,
        url: "https://example.test/rate/1/$(touch must-not-exist)",
        caption: "Express your rating",
        expected_output: expected_output
      )

      assert_predicate result.status, :success?
      assert_path_exists expected_output
      assert_not File.exist?(marker)
    end
  end

  test "raises when RS_PDF exits unsuccessfully" do
    runner = RsPdfRunner.new(
      jar_path: "unused",
      command_prefix: [RbConfig.ruby, "-e", "warn 'conversion failed'; exit 7", "--"]
    )

    error = assert_raises(RsPdfRunner::ExecutionError) do
      runner.call(
        input_path: "Reader.pdf",
        output_path: Dir.tmpdir,
        url: "https://example.test/rate",
        caption: "Express your rating",
        expected_output: File.join(Dir.tmpdir, "never-created.pdf")
      )
    end

    assert_includes error.message, "exit status 7"
    assert_includes error.message, "conversion failed"
  end

  test "raises when the process does not produce the expected PDF" do
    runner = RsPdfRunner.new(
      jar_path: "unused",
      command_prefix: [RbConfig.ruby, "-e", "exit 0", "--"]
    )

    assert_raises(RsPdfRunner::ExecutionError) do
      runner.call(
        input_path: "Reader.pdf",
        output_path: Dir.tmpdir,
        url: "https://example.test/rate",
        caption: "Express your rating",
        expected_output: File.join(Dir.tmpdir, "never-created.pdf")
      )
    end
  end

  test "terminates a process that exceeds its timeout" do
    runner = RsPdfRunner.new(
      jar_path: "unused",
      timeout: 0.1,
      command_prefix: [RbConfig.ruby, "-e", "sleep 10", "--"]
    )

    error = assert_raises(RsPdfRunner::ExecutionError) do
      runner.call(
        input_path: "Reader.pdf",
        output_path: Dir.tmpdir,
        url: "https://example.test/rate",
        caption: "Express your rating",
        expected_output: File.join(Dir.tmpdir, "never-created.pdf")
      )
    end

    assert_includes error.message, "timeout"
  end

end
