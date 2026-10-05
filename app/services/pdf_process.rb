class PdfProcess

  class OutputTooLarge < RuntimeError; end

  Result = Struct.new(:stdout, :stderr, :status, keyword_init: true)
  OUTPUT_LIMIT = 1024 * 1024
  BUFFER_SIZE = 16 * 1024
  POLL_INTERVAL = 0.02
  TERMINATION_GRACE = 2

  def call(command, deadline:)
    deadline.check!
    stdout_reader, stdout_writer = IO.pipe
    stderr_reader, stderr_writer = IO.pipe
    stdout = +"".b
    stderr = +"".b
    streams = {stdout_reader => stdout, stderr_reader => stderr}
    finished = false
    options = {in: File::NULL, out: stdout_writer, err: stderr_writer, close_others: true}
    options[:pgroup] = true unless Gem.win_platform?
    process_id = Process.spawn(*command, **options)
    stdout_writer.close
    stderr_writer.close
    status = nil

    loop do
      deadline.check!
      ready = IO.select(streams.keys, nil, nil, [POLL_INTERVAL, deadline.remaining].min)
      ready&.first&.each do |stream|
        chunk = stream.read_nonblock(BUFFER_SIZE, exception: false)
        case chunk
        when nil
          streams.delete(stream)
          stream.close
        when :wait_readable
          next
        else
          output = streams.fetch(stream)
          raise OutputTooLarge, "PDF process output exceeds its limit" if output.bytesize + chunk.bytesize > OUTPUT_LIMIT
          output << chunk
        end
      end
      completed = Process.wait2(process_id, Process::WNOHANG) unless status
      status = completed.last if completed
      break if status && streams.empty?
    end
    deadline.check!
    finished = true
    Result.new(stdout: stdout.force_encoding("UTF-8"), stderr: stderr.force_encoding("UTF-8"), status: status)
  ensure
    begin
      terminate(process_id) if process_id && !finished
    ensure
      [stdout_reader, stdout_writer, stderr_reader, stderr_writer].compact.each { |stream| stream.close unless stream.closed? }
    end
  end

  private

  def terminate(process_id)
    target = Gem.win_platform? ? process_id : -process_id
    signal("TERM", target)
    expiration = Process.clock_gettime(Process::CLOCK_MONOTONIC) + TERMINATION_GRACE
    loop do
      break if Process.waitpid(process_id, Process::WNOHANG)
      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= expiration
      sleep POLL_INTERVAL
    end
  rescue Errno::ECHILD
    nil
  ensure
    # Also stop descendants that kept running after the direct child terminated.
    signal("KILL", target) if target
    begin
      Process.waitpid(process_id)
    rescue Errno::ECHILD
      nil
    end
  end

  def signal(name, target)
    Process.kill(name, target)
  rescue Errno::ESRCH
    nil
  end

end
