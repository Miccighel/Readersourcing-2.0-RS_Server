class Rating < ApplicationRecord

	belongs_to :user
	belongs_to :publication

	validates :publication_id, uniqueness: {scope: :user_id}
	validates :score, :original_score, presence: true, numericality: {
		only_integer: true,
		greater_than_or_equal_to: 0,
		less_than_or_equal_to: 100
	}
	validate :reject_boolean_scores

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

	private

	def reject_boolean_scores
		# Rails casts false to zero before numericality validation.
		[:score, :original_score].each do |attribute|
			if public_send("#{attribute}_before_type_cast") == false
				errors.add(attribute, :not_a_number)
			end
		end
	end

end
