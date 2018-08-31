class PasswordMailer < ApplicationMailer

	def forgot(user, reset_token)
		@user = user
		@reset_token = reset_token
		mail(
			from: 'R@SM <from.example.com>',
			to: "#{@user.first_name} #{@user.last_name} <#{@user.email}>",
			subject: 'R@SM - Recupero Password',
			:template_path => 'passwords',
			:template_name => 'forgot'
		)
	end

	def reset(user, new_password)
		@user = user
		@new_password = new_password
		mail(
			from: 'R@SM <from.example.com>',
			to: "#{@user.first_name} #{@user.last_name} <#{@user.email}>",
			subject: 'R@SM - Password Reset',
			:template_path => 'passwords',
			:template_name => 'reset'
		)
	end

end
