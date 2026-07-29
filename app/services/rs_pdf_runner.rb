require "tempfile"
require "timeout"

class RsPdfRunner

  class ExecutionError < RuntimeError; end

  Result = Struct.new(:stdout, :stderr, :status, keyword_init: true)

  DEFAULT_TIMEOUT = 60

  def initialize(
    jar_path:,
    timeout: Integer(ENV.fetch("RS_PDF_PROCESS_TIMEOUT", DEFAULT_TIMEOUT)),
    command_prefix: nil
  )
    @jar_path = jar_path.to_s
    @timeout = timeout
    @command_prefix = command_prefix || ["java", "-jar", @jar_path]
  end

  def call(input_path:, output_path:, url:, caption:, expected_output:)
    command = @command_prefix + [
      "-pIn", input_path.to_s,
      "-pOut", output_path.to_s,
      "-u", url.to_s,
      "-c", caption.to_s
    ]

    stdout, stderr, status = execute(command)

    unless status.success?
      raise ExecutionError, "RS_PDF failed with exit status #{status.exitstatus}: #{safe_error(stderr)}"
    end
    unless File.file?(expected_output)
      raise ExecutionError, "RS_PDF completed without producing the expected annotated publication"
    end

    Result.new(stdout: stdout, stderr: stderr, status: status)
  rescue Errno::ENOENT => error
    raise ExecutionError, "RS_PDF could not be started: #{error.message}"
  end

  private

  def execute(command)
    Tempfile.create("rs-pdf-stdout") do |stdout_file|
      Tempfile.create("rs-pdf-stderr") do |stderr_file|
        process_id = Process.spawn(*command, out: stdout_file, err: stderr_file)
        status = wait_for(process_id)

        stdout_file.rewind
        stderr_file.rewind
        return [stdout_file.read, stderr_file.read, status]
      end
    end
  end

  def wait_for(process_id)
    Timeout.timeout(@timeout) do
      _, status = Process.wait2(process_id)
      status
    end
  rescue Timeout::Error
    terminate(process_id)
    raise ExecutionError, "RS_PDF exceeded the configured #{@timeout}-second timeout"
  end

  def terminate(process_id)
    Process.kill("TERM", process_id)
    Timeout.timeout(2) { Process.wait(process_id) }
  rescue Timeout::Error
    Process.kill("KILL", process_id)
    Process.wait(process_id)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  end

  def safe_error(stderr)
    message = stderr.to_s.lines.last.to_s.strip
    message.present? ? message : "no error output"
  end

end
