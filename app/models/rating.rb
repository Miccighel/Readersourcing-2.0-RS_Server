class Rating < ApplicationRecord

	belongs_to :user
	belongs_to :publication

	def normalize_score
		self.score / 100.0
	end

	def compute_scores
		logger.info "Computing scores with SM Model"
		readersourcing = SMStrategy.new self
		readersourcing.compute_scores
		logger.info "Computing scores with TrueReview Model"
		readersourcing = TrueReviewStrategy.new self
		readersourcing.compute_scores
	end

end
