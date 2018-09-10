class Rating < ApplicationRecord

	belongs_to :user
	belongs_to :publication

	def normalize_score
		self.score/100.0
	end

end
