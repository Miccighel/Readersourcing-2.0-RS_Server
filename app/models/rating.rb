class Rating < ApplicationRecord

	belongs_to :user
	belongs_to :publication

	validates :publication_id, uniqueness: {scope: :user_id}

	def normalize_score
		self.score / 100.0
	end

	def pretty_score
		"#{self.score}/100"
	end

	def compute_scores
		logger.info "Computing scores with RSM Model"
		readersourcing = Readersourcing.new RsmStrategy.new self
		readersourcing.compute_scores
		logger.info "Computing scores with TRM Model"
		readersourcing = Readersourcing.new TrmStrategy.new self
		readersourcing.compute_scores
	end

end
