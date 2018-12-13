class PasswordMailer < ApplicationMailer

	def update(user)
		@user = user
		mail(
			to: "#{@user.first_name} #{@user.last_name} <#{@user.email}>",
			subject: "#{I18n.t("mails.labels.platform_name")} - #{I18n.t("mails.subject.password_update")}",
			:template_path => 'passwords',
			:template_name => 'mails/update'
		)
	end

	def forgot(user, reset_url)
		@user = user
		@reset_url = reset_url
		mail(
			to: "#{@user.first_name} #{@user.last_name} <#{@user.email}>",
			subject: "#{I18n.t("mails.labels.platform_name")} - #{I18n.t("mails.subject.password_recovery")}",
			:template_path => 'passwords',
			:template_name => 'mails/forgot'
		)
	end

	def reset(user, new_password)
		@user = user
		@new_password = new_password
		mail(
			to: "#{@user.first_name} #{@user.last_name} <#{@user.email}>",
			subject: "#{I18n.t("mails.labels.platform_name")} - #{I18n.t("mails.subject.password_reset")}",
			:template_path => 'passwords',
			:template_name => 'mails/reset'
		)
	end

end
