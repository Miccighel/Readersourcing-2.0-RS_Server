class PasswordMailer < ApplicationMailer

	def update(user)
		@user = user
		mail(
			from: "#{I18n.t("mails.labels.platform_name")} <from@example.com>",
			to: "#{@user.first_name} #{@user.last_name} <#{@user.email}>",
			subject: "#{I18n.t("mails.labels.platform_name")} - #{I18n.t("mails.subject.password_update")}",
			:template_path => 'passwords',
			:template_name => 'update'
		)
	end

	def forgot(user, reset_token)
		@user = user
		@reset_token = reset_token
		mail(
			from: "#{I18n.t("mails.labels.platform_name")} <from@example.com>",
			to: "#{@user.first_name} #{@user.last_name} <#{@user.email}>",
			subject: "#{I18n.t("mails.labels.platform_name")} - #{I18n.t("mails.subject.password_recovery")}",
			:template_path => 'passwords',
			:template_name => 'forgot'
		)
	end

	def reset(user, new_password)
		@user = user
		@new_password = new_password
		mail(
			from: "#{I18n.t("mails.labels.platform_name")} <from@example.com>",
			to: "#{@user.first_name} #{@user.last_name} <#{@user.email}>",
			subject: "#{I18n.t("mails.labels.platform_name")} - #{I18n.t("mails.subject.password_reset")}",
			:template_path => 'passwords',
			:template_name => 'reset'
		)
	end

end
