require "test_helper"
require "rbconfig"
require "json"

class PdfProcessTest < ActiveSupport::TestCase

  test "collects a completed process without invoking a shell" do
    result = PdfProcess.new.call([RbConfig.ruby, "-e", "puts ARGV.first; warn 'detail'", "--", "$(touch never-created)"], deadline: PdfOperationDeadline.new)

    assert result.status.success?
    assert_equal "$(touch never-created)\n", result.stdout
    assert_equal "detail\n", result.stderr
  end

  test "kills and reaps a process that ignores TERM" do
    Dir.mktmpdir("rs-process-timeout-") do |directory|
      pid_path = File.join(directory, "pid")
      script = "trap('TERM') {}; File.write(ARGV.first, Process.pid); sleep 20"
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      assert_raises(PdfOperationDeadline::Exceeded) do
        PdfProcess.new.call([RbConfig.ruby, "-e", script, "--", pid_path], deadline: PdfOperationDeadline.new(timeout: 0.5))
      end

      assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 4
      pid = Integer(File.read(pid_path))
      assert_raises(Errno::ECHILD) { Process.waitpid(pid, Process::WNOHANG) }
      assert_raises(Errno::ESRCH) { Process.kill(0, pid) }
    end
  end

  test "also stops descendants of a timed out process" do
    skip "Process groups are not available" if Gem.win_platform?
    Dir.mktmpdir("rs-process-group-") do |directory|
      heartbeat = File.join(directory, "heartbeat")
      script = <<~RUBY
        fork do
          trap('TERM') {}
          loop do
            File.write(ARGV.first, Process.clock_gettime(Process::CLOCK_MONOTONIC))
            sleep 0.02
          end
        end
        sleep 20
      RUBY
      assert_raises(PdfOperationDeadline::Exceeded) do
        PdfProcess.new.call([RbConfig.ruby, "-e", script, "--", heartbeat], deadline: PdfOperationDeadline.new(timeout: 0.5))
      end
      last = File.read(heartbeat)
      sleep 0.1
      assert_equal last, File.read(heartbeat)
    end
  end

  test "stops a process whose output exceeds the bounded result" do
    %w[STDOUT STDERR].each do |stream|
      script = "#{stream}.sync = true; #{stream}.puts 'x' * (2 * 1024 * 1024); sleep 20"

      assert_raises(PdfProcess::OutputTooLarge) do
        PdfProcess.new.call([RbConfig.ruby, "-e", script], deadline: PdfOperationDeadline.new(timeout: 5))
      end
    end
  end

end
