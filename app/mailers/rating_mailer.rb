class RatingMailer < ApplicationMailer

	def confirm(user, score, link)
		@user = user
		@score = score
		@link = link
		mail(
			to: "#{@user.first_name} #{@user.last_name} <#{@user.email}>",
			subject: "#{I18n.t("mails.labels.platform_name")} - #{I18n.t("mails.subject.rating_confirm")}",
			:template_path => 'ratings',
			:template_name => 'confirm'
		)
	end

end
