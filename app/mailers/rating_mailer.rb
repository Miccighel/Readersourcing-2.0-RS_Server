class RatingMailer < ApplicationMailer

	def confirm(user, score, link)
		@user = user
		@score = score
		@link = link
		mail(
			from: 'R@SM <from.example.com>',
			to: "#{@user.first_name} #{@user.last_name} <#{@user.email}>",
			subject: 'R@SM - Conferma Assegnamento Giudizio',
			:template_path => 'ratings',
			:template_name => 'confirm'
		)
	end

end
