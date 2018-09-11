class SMStrategy < ReadersourcingStrategy

	def initialize(rating)
		@rating = rating
		@user = @rating.user
		@publication = @rating.publication
	end

	def compute

		puts "Saving values at time t(i)"

		old_publication_steadiness = @publication.steadiness
		old_publication_score = @publication.score
		old_user_steadiness = @user.steadiness
		old_rating_goodness = 1 - Math.sqrt((@rating.normalize_score - old_publication_score).abs)
		old_user_score = @user.score

		puts "Publication steadiness at time t(i) #{old_publication_steadiness}"
		puts "Publication score at time t(i) #{old_publication_score}"
		puts "User steadiness at time t(i) #{old_user_steadiness}"
		puts "Rating goodness at time t(i) #{old_rating_goodness}"
		puts "User score at time t(i) #{old_user_score}"

		puts "Updating values at time t(i+1)"

		@publication.steadiness = old_publication_steadiness + @user.score
		@publication.score = ((old_publication_steadiness * old_publication_score) + (old_user_score * @rating.normalize_score)) / @publication.steadiness
		@user.steadiness = old_user_steadiness + @publication.steadiness
		@rating.goodness =  1 - Math.sqrt((@rating.normalize_score - @publication.score).abs)
		@user.score = ((old_user_steadiness * old_user_score) + (@publication.steadiness * @rating.goodness)) / @user.steadiness

		puts "Publication steadiness at time t(i+1) #{@publication.steadiness}"
		puts "Publication score at time t(i+1) #{@publication.score}"
		puts "User steadiness at time t(i+1) #{@user.steadiness}"
		puts "Rating goodness at time t(i+1) #{@rating.goodness}"
		puts "User score at time t(i+1) #{@user.score}"

		@publication.save
		@user.save
		@rating.save

		previous_users = @publication.other_users(@user)

		previous_users.each do |previous_user|

			puts "Saving previous values at time t(i)"

			old_previous_user_steadiness = previous_user.steadiness
			old_previous_user_score = previous_user.score
			old_rating = previous_user.given_rating(@publication)
			old_rating_goodness =  old_rating.goodness
			
			puts "Previous user steadiness at time t(i) #{old_previous_user_steadiness}"
			puts "Previous rating goodness at time t(i) #{old_rating_goodness}"
			puts "Previous user score at time t(i) #{old_previous_user_score}"

			puts "Updating previous values at time t(i+1)"

			old_rating.goodness =  1 - Math.sqrt((old_rating.normalize_score - @publication.score).abs)
			previous_user.steadiness = old_previous_user_steadiness + old_user_score
			previous_user.score = ((old_previous_user_steadiness * old_previous_user_score) - (old_publication_steadiness * old_rating_goodness) + (@publication.steadiness * old_rating.goodness)) / previous_user.steadiness

			puts "Previous user steadiness at time t(i+1) #{previous_user.steadiness}"
			puts "Previous rating goodness at time t(i+1) #{old_rating.goodness}"
			puts "Previous user score at time t(i+1) #{previous_user.score}"

			old_rating.save
			previous_user.save

		end

	end

end