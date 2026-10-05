require "test_helper"

class PdfOperationDeadlineTest < ActiveSupport::TestCase

  test "a phase can shorten but cannot renew the operation deadline" do
    now = 10.0
    deadline = PdfOperationDeadline.new(timeout: 10, clock: -> { now })
    now += 7
    phase = deadline.limit(60)

    assert_in_delta 3, phase.remaining
    assert_in_delta 1, deadline.limit(1).remaining
    now += 4
    assert_raises(PdfOperationDeadline::Exceeded) { phase.check! }
    assert_raises(PdfOperationDeadline::Exceeded) { deadline.limit(60).check! }
  end

  test "elapsed wall clock time does not depend on the system calendar" do
    now = 10.0
    deadline = PdfOperationDeadline.new(timeout: 10, clock: -> { now })

    travel 1.year do
      assert_in_delta 10, deadline.remaining
    end
    now += 11
    assert_raises(PdfOperationDeadline::Exceeded) { deadline.check! }
  end

  test "rejects timeouts that cannot bound an operation" do
    [0, -1, Float::INFINITY, Float::NAN, "many"].each do |value|
      assert_raises(ArgumentError) { PdfOperationDeadline.new(timeout: value) }
    end
  end

  test "bounds a network wait even when it does not return control" do
    assert_raises(PdfOperationDeadline::Exceeded) do
      PdfOperationDeadline.new(timeout: 0.1).during { sleep 20 }
    end
  end

end
