class TrmStrategy < ReadersourcingStrategy

	def initialize(rating)
		@publication = rating.publication
		@ratings = rating.publication.ratings_history
	end

	def compute_scores

		scores = []
		users = []

		# FOR EACH RATING Xi
		@ratings.each do |rating|
			scores.push rating.normalize_score
			users.push rating.user
		end

		@ratings.each_with_index do |rating, index|
			if index > 0 and index < (@ratings.size - 1)
				past_ratings = scores[0..(index - 1)]
				future_ratings = scores[(index + 1)..(@ratings.size - 1)]
				qi_past = mean(past_ratings)
				qi_future = mean(future_ratings)

				rating.informativeness = quadratic_loss(qi_past, qi_future).round(16)
				rating.accuracy_loss = quadratic_loss(rating.normalize_score, qi_future).round(16)
				rating.bonus = rating.informativeness * logistic_fuction(rating.accuracy_loss).round(16)
				rating.save

				puts "Informativeness: #{rating.informativeness}"
				puts "Accuracy Loss: #{rating.accuracy_loss}"
				puts "Rating Bonus: #{rating.bonus}"
			end
		end

		puts "Publication score at time t(i) #{@publication.score_trm}"
		@publication.score_trm = mean(scores).round(32)
		@publication.save
		puts "Publication score at time t(i+1) #{@publication.score_trm}"

		users.each do |user|
			puts "User bonus at time t(i) #{user.bonus}"
			bonuses = []
			user.given_ratings.each {|rating| bonuses.push rating.bonus}
			user.bonus = mean(bonuses).round(32)
			puts "User bonus at time t(i+1) #{user.bonus}"
			user.save
		end
	end

	private

	def mean(array)
		array.inject {|sum, el| sum + el}.to_f / array.size
	end

	def quadratic_loss(a, b)
		(a - b) ** 2
	end

	def logistic_fuction(value)
		# https://en.wikipedia.org/wiki/Logistic_function
		1 / 1 + (Math.exp((-1 * (value - 0.5))))
	end

end