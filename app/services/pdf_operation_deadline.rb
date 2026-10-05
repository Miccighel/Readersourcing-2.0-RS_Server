require "timeout"

class PdfOperationDeadline

  class Exceeded < RuntimeError; end

  DEFAULT_TIMEOUT = 120

  def initialize(timeout: ENV.fetch("RS_PDF_TOTAL_TIMEOUT", DEFAULT_TIMEOUT), clock: nil, expires_at: nil)
    seconds = Float(timeout)
    raise ArgumentError, "PDF timeout must be positive and finite" unless seconds.finite? && seconds.positive?

    @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    @expires_at = [@clock.call + seconds, expires_at].compact.min
  end

  def limit(seconds)
    self.class.new(timeout: seconds, clock: @clock, expires_at: @expires_at)
  end

  def remaining
    seconds = @expires_at - @clock.call
    raise Exceeded, "The PDF operation exceeded its time limit" unless seconds.positive?

    seconds
  end

  def check!
    remaining
    self
  end

  # Used only around network I/O, never around a database transaction or PDF parsing.
  def during
    Timeout.timeout(remaining, Exceeded) do
      result = yield self
      check!
      result
    end
  end

end
