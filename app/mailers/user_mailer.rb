class UserMailer < ApplicationMailer

	def successful(user)
		@user = user
		mail(
			to: "#{@user.first_name} #{@user.last_name} <#{@user.email}>",
			subject: "#{I18n.t("mails.labels.platform_name")} - #{I18n.t("mails.subject.registration_confirm")}",
			:template_path => 'users',
			:template_name => 'successful'
		)
	end

end
