class RsmStrategy < ReadersourcingStrategy

	def initialize(rating)
		@rating = rating
		@user = @rating.user
		@publication = @rating.publication
	end

	def compute_scores

		puts "Saving values at time t(i)"

		old_publication_steadiness = @publication.steadiness
		old_publication_score = @publication.score_rsm
		old_user_steadiness = @user.steadiness
		old_rating_goodness = @rating.goodness
		old_user_score = @user.score

		puts "Publication steadiness at time t(i) #{old_publication_steadiness}"
		puts "Publication score at time t(i) #{old_publication_score}"
		puts "User steadiness at time t(i) #{old_user_steadiness}"
		puts "Rating goodness at time t(i) #{old_rating_goodness}"
		puts "User score at time t(i) #{old_user_score}"

		puts "Updating values at time t(i+1)"

		@publication.steadiness = (old_publication_steadiness + @user.score)
		@publication.score_rsm = (((old_publication_steadiness * old_publication_score) + (old_user_score * @rating.normalize_score)) / @publication.steadiness)
		@rating.goodness =  (1 - Math.sqrt((@rating.normalize_score - @publication.score_rsm).abs))
		@user.steadiness = (old_user_steadiness + @publication.steadiness)
		@user.score = (((old_user_steadiness * old_user_score) + (@publication.steadiness * @rating.goodness)) / @user.steadiness)

		puts "Publication steadiness at time t(i+1) #{@publication.steadiness}"
		puts "Publication score at time t(i+1) #{@publication.score_rsm}"
		puts "User steadiness at time t(i+1) #{@user.steadiness}"
		puts "Rating goodness at time t(i+1) #{@rating.goodness}"
		puts "User score at time t(i+1) #{@user.score}"

		@publication.steadiness = @publication.steadiness.round(32)
		@publication.score_rsm = @publication.score_rsm.round(32)
		@user.steadiness = @user.steadiness.round(32)
		@rating.goodness = @rating.goodness.round(32)
		@user.score = @user.score.round(32)

		@publication.save
		@user.save
		@rating.save

		previous_users = @publication.other_users(@user)

		previous_users.each do |previous_user|

			puts "Saving previous values at time t(i)"

			old_previous_user_steadiness = previous_user.steadiness
			old_previous_user_score = previous_user.score
			old_previous_rating = previous_user.given_rating(@publication)
			old_previous_rating_goodness =  old_previous_rating.goodness
			
			puts "Previous user steadiness at time t(i) #{old_previous_user_steadiness}"
			puts "Previous rating goodness at time t(i) #{old_rating_goodness}"
			puts "Previous user score at time t(i) #{old_previous_user_score}"

			puts "Updating previous values at time t(i+1)"

			old_previous_rating.goodness =  (1 - Math.sqrt((old_previous_rating.normalize_score - @publication.score_rsm).abs))
			previous_user.steadiness = (old_previous_user_steadiness + old_user_score)
			previous_user.score = (
				(old_previous_user_steadiness * old_previous_user_score) -
				(old_publication_steadiness * old_previous_rating_goodness) +
				(@publication.steadiness * old_previous_rating.goodness)
			) / previous_user.steadiness

			puts "Previous user steadiness at time t(i+1) #{previous_user.steadiness}"
			puts "Previous rating goodness at time t(i+1) #{old_previous_rating.goodness}"
			puts "Previous user score at time t(i+1) #{previous_user.score}"

			old_previous_rating.save
			previous_user.save

		end

	end

end