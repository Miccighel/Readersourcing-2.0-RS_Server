require "test_helper"
require "timeout"

class RatingSubmissionConcurrencyTest < ActiveSupport::TestCase

  self.use_transactional_tests = false

  setup do
    @users = []
    @publication_urls = []
    @threads = []
  end

  teardown do
    @threads.each do |thread|
      thread.kill if thread.alive?
      thread.join
    end
    Rating.where(user_id: @users.map(&:id)).delete_all
    Publication.where(pdf_url: @publication_urls).delete_all
    User.where(id: @users.map(&:id)).delete_all
  end

  test "waits for the shared database lock before writing a rating or its scores" do
    user = new_reader
    publication = new_publication
    ready = Queue.new
    worker = nil

    capture_io do
      Rating.transaction do
        Rating.connection.execute("SELECT pg_advisory_xact_lock(#{RatingSubmission::LOCK_NAMESPACE}, #{RatingSubmission::LOCK_ID})")
        worker = start_worker do
          ready << Rating.connection.select_value("SELECT pg_backend_pid()").to_i
          submit(user.id, publication.id, 72)
        end
        pid = Timeout.timeout(5) { ready.pop }
        Timeout.timeout(5) do
          until Rating.uncached { Rating.connection.select_value("SELECT EXISTS (SELECT 1 FROM pg_locks WHERE pid = #{pid} AND locktype = 'advisory' AND NOT granted)") }
            Thread.pass
          end
        end

        assert_not Rating.exists?(user_id: user.id, publication_id: publication.id)
        assert_equal BigDecimal("0"), publication.reload.score_rsm
        assert_equal BigDecimal("0.000001"), user.reload.score
      end

      assert worker_result(worker)
    end

    assert_equal 1, Rating.where(user_id: user.id, publication_id: publication.id).count
    assert_equal BigDecimal("0.72"), publication.reload.score_trm
  end

  test "simultaneous submissions by one reader create only one rating and one unknown publication" do
    user = new_reader
    url = new_publication_url
    candidates = [35, 80].map do |score|
      Rating.new(user: User.find(user.id), publication: Publication.new(pdf_url: url), score: score, original_score: score)
    end

    results = nil
    capture_io { results = concurrently(candidates) { |rating| RatingSubmission.new(rating).call } }

    assert_equal [false, true], results.sort_by { |result| result ? 1 : 0 }
    publication = Publication.find_by!(pdf_url: url)
    assert_equal 1, Publication.where(pdf_url: url).count
    assert_equal 1, Rating.where(user_id: user.id, publication_id: publication.id).count
    winner = Rating.find_by!(user_id: user.id, publication_id: publication.id)
    assert_equal BigDecimal(winner.score.to_s) / 100, publication.score_rsm
    assert_equal publication.score_rsm, publication.score_trm
    assert_equal BigDecimal("0.000001"), publication.steadiness
    assert_equal BigDecimal("1"), user.reload.score
  end

  test "concurrent readers produce the same RSM and TRM state as their serial insertion order" do
    readers = Array.new(3) { new_reader }
    publication = new_publication
    scores = [20, 75, 60]
    candidates = readers.zip(scores).map do |reader, score|
      Rating.new(user: User.find(reader.id), publication: Publication.find(publication.id), score: score, original_score: score)
    end
    baseline_readers = Array.new(3) { new_reader }
    baseline_publication = new_publication

    capture_io do
      assert concurrently(candidates) { |rating| RatingSubmission.new(rating).call }.all?
      Rating.where(publication_id: publication.id).order(:id).each do |rating|
        index = readers.index { |reader| reader.id == rating.user_id }
        assert submit(baseline_readers[index].id, baseline_publication.id, scores[index])
      end
    end

    assert_equal metrics(baseline_readers, [baseline_publication]), metrics(readers, [publication])
    assert_equal 3, publication.ratings.count
  end

  test "concurrent ratings of different publications retain the shared reader reputation" do
    user = new_reader
    publications = Array.new(2) { new_publication }
    scores = [25, 85]
    candidates = publications.zip(scores).map do |publication, score|
      Rating.new(user: User.find(user.id), publication: publication, score: score, original_score: score)
    end
    baseline_user = new_reader
    baseline_publications = Array.new(2) { new_publication }

    capture_io do
      assert concurrently(candidates) { |rating| RatingSubmission.new(rating).call }.all?
      Rating.where(user_id: user.id).order(:id).each do |rating|
        index = publications.index { |publication| publication.id == rating.publication_id }
        assert submit(baseline_user.id, baseline_publications[index].id, scores[index])
      end
    end

    assert_equal metrics([baseline_user], baseline_publications), metrics([user], publications)
    assert_equal 2, Rating.where(user_id: user.id).count
  end

  test "confirmation runs only after the outermost transaction commits" do
    user = new_reader
    publication = new_publication
    confirmations = []

    capture_io do
      Rating.transaction do
        saved = submit(user.id, publication.id, 72) do
          confirmations << [Rating.connection.open_transactions, Publication.find(publication.id).score_trm]
        end
        assert saved
        assert_empty confirmations
      end
    end

    assert_equal [[0, BigDecimal("0.72")]], confirmations
  end

  test "an outer rollback discards the confirmation and all rating calculations" do
    user = new_reader
    publication = new_publication
    before = metrics([user], [publication])
    confirmations = []

    capture_io do
      Rating.transaction do
        assert submit(user.id, publication.id, 72) { confirmations << :sent }
        raise ActiveRecord::Rollback
      end
    end

    assert_empty confirmations
    assert_not Rating.exists?(user_id: user.id, publication_id: publication.id)
    assert_equal before, metrics([user], [publication])
    capture_io { assert submit(user.id, publication.id, 72) }
  end

  private

  def new_reader
    User.create!(email: "rating-#{SecureRandom.hex(8)}@example.test", password: "password").tap { |user| @users << user }
  end

  def new_publication_url
    "https://example.test/rating-#{SecureRandom.hex(8)}.pdf".tap { |url| @publication_urls << url }
  end

  def new_publication
    Publication.create!(pdf_url: new_publication_url)
  end

  def submit(user_id, publication_id, score, &confirmation)
    rating = Rating.new(user: User.find(user_id), publication: Publication.find(publication_id), score: score, original_score: score)
    RatingSubmission.new(rating).call(&confirmation)
  end

  def start_worker(&block)
    Thread.new do
      Thread.current.report_on_exception = false
      ActiveRecord::Base.connection_pool.with_connection(&block)
    end.tap { |thread| @threads << thread }
  end

  def worker_result(thread)
    raise "Rating worker did not finish" unless thread.join(10)

    thread.value
  end

  def concurrently(items)
    ready = Queue.new
    start = Queue.new
    workers = items.map do |item|
      start_worker do
        ready << true
        Timeout.timeout(5) { start.pop }
        yield item
      end
    end
    Timeout.timeout(5) { items.size.times { ready.pop } }
    items.size.times { start << true }
    workers.map { |worker| worker_result(worker) }
  end

  def metrics(readers, publications)
    [
      readers.map { |reader| reader.reload.attributes.values_at("score", "steadiness", "bonus") },
      publications.map { |publication| publication.reload.attributes.values_at("score_rsm", "score_trm", "steadiness") },
      readers.map do |reader|
        publications.map do |publication|
          Rating.find_by(user_id: reader.id, publication_id: publication.id)&.attributes&.values_at("goodness", "informativeness", "accuracy_loss", "bonus")
        end
      end
    ]
  end

end
