class RsPdfRunner

  class ExecutionError < RuntimeError; end
  class ExecutionTimeout < ExecutionError; end

  Result = Struct.new(:stdout, :stderr, :status, keyword_init: true)

  DEFAULT_TIMEOUT = 60

  def initialize(
    jar_path:,
    timeout: Integer(ENV.fetch("RS_PDF_PROCESS_TIMEOUT", DEFAULT_TIMEOUT)),
    command_prefix: nil,
    process: PdfProcess.new
  )
    @jar_path = jar_path.to_s
    @timeout = timeout
    @command_prefix = command_prefix || ["java", "-jar", @jar_path]
    @process = process
  end

  def call(input_path:, output_path:, url:, caption:, expected_output:, deadline: PdfOperationDeadline.new)
    command = @command_prefix + [
      "-pIn", input_path.to_s,
      "-pOut", output_path.to_s,
      "-u", url.to_s,
      "-c", caption.to_s
    ]

    result = @process.call(command, deadline: deadline.limit(@timeout))
    stdout, stderr, status = result.stdout, result.stderr, result.status

    unless status.success?
      raise ExecutionError, "RS_PDF failed with exit status #{status.exitstatus}: #{safe_error(stderr)}"
    end
    unless File.file?(expected_output)
      raise ExecutionError, "RS_PDF completed without producing the expected annotated publication"
    end

    Result.new(stdout: stdout, stderr: stderr, status: status)
  rescue Errno::ENOENT => error
    raise ExecutionError, "RS_PDF could not be started: #{error.message}"
  rescue PdfOperationDeadline::Exceeded
    raise ExecutionTimeout, "RS_PDF exceeded its configured timeout or the remaining PDF operation time"
  rescue PdfProcess::OutputTooLarge => error
    raise ExecutionError, error.message
  end

  private

  def safe_error(stderr)
    message = stderr.to_s.lines.last.to_s.strip
    message.present? ? message : "no error output"
  end

end
