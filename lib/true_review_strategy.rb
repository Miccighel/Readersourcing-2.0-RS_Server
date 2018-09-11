class TrueReviewStrategy < ReadersourcingStrategy

	def initialize(ratings)
		@ratings = ratings
	end

	def compute
		# FOR EVERY RATING Xi
		scores = []
		@ratings.each {|rating| scores.push rating.normalize_score}
		@ratings.each_with_index do |rating, index|
			if index > 0 and index < (@ratings.size - 1)
				puts "Rating data"
				puts "ID: #{rating.id}"
				puts "Score: #{rating.normalize_score}"
				puts "Created At: #{rating.created_at}"
				puts "Informativeness: #{rating.informativeness}"
				puts "Accuracy Loss: #{rating.accuracy_loss}"

				past_ratings = scores[0..(index - 1)]
				future_ratings = scores[(index + 1)..(@ratings.size - 1)]
				qi_past = mean(past_ratings)
				qi_future = mean(future_ratings)
				rating.informativeness = quadratic_loss(qi_past, qi_future)
				rating.accuracy_loss = quadratic_loss(rating.normalize_score, qi_future)
				rating.save

				puts "Updated Informativeness #{rating.informativeness}"
				puts "Updated Accuracy Loss #{rating.accuracy_loss}"
			end
		end
	end

	private

	def mean(array)
		array.inject {|sum, el| sum + el}.to_f / array.size
	end

	def quadratic_loss(a, b)
		(a - b) ** 2
	end

end