class RatingSubmission

  attr_reader :confirmation_failed

  LOCK_NAMESPACE = 0x52533230
  LOCK_ID = 1

  def initialize(rating)
    @rating = rating
    @confirmation_failed = false
  end

  def call(attributes: {}, &confirmation)
    @rating.assign_attributes(attributes)
    return false unless @rating.valid?

    new_rating = @rating.new_record?
    saved = false
    Rating.transaction(requires_new: true) do |transaction|
      # Reader scores are shared across publications, so every rating write uses this lock.
      Rating.connection.execute("SELECT pg_advisory_xact_lock(#{LOCK_NAMESPACE}, #{LOCK_ID})")
      Rating.uncached do
        unless new_rating
          @rating.reload
          @rating.assign_attributes(attributes)
        end
        refresh_associations
        raise ActiveRecord::Rollback unless @rating.save

        @rating.compute_scores if new_rating
        transaction.after_commit { confirm(confirmation) } if confirmation
        saved = true
      end
    end
    saved
  rescue ActiveRecord::RecordNotUnique
    @rating.errors.add(:publication_id, :taken)
    false
  rescue ActiveRecord::RecordInvalid
    @rating.errors.add(:base, I18n.t("errors.messages.rating_unsuccessful"))
    false
  end

  private

  def refresh_associations
    @rating.user = User.find(@rating.user_id)
    publication = @rating.publication
    @rating.publication = if publication.new_record?
      Publication.find_by(pdf_url: publication.pdf_url) || publication
    else
      publication.reload
    end
  end

  def confirm(confirmation)
    confirmation.call
  rescue StandardError => error
    @confirmation_failed = true
    Rails.logger.warn("Rating #{@rating.id} was saved, but confirmation failed (#{error.class.name})")
  end

end
