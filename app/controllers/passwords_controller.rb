class PasswordsController < ApplicationController

	include ::ActionView::Layouts

	layout "application", only: [:forgot, :reset]

	skip_before_action :authenticate_request, only: [:forgot, :reset]

	before_action :set_error_manager, only: [:update, :forgot, :reset]

	# POST /password/update.json
	def update
		inserted_password = params[:password]
		inserted_password_confirmation = params[:password_confirmation]
		if inserted_password == inserted_password_confirmation
			current_user.password = inserted_password
			if current_user.save
				PasswordMailer.update(current_user).deliver
				render "shared/success", status: :ok, locals: {message: I18n.t("confirmations.messages.password_update_successful")}
			else
				current_user.errors.each {|error| @error_manager.add_error(error)}
				render "shared/errors", status: :unprocessable_entity, locals: {errors: @error_manager.get_errors}
			end
		else
			@error_manager.add_error(I18n.t("errors.messages.password_does_not_match"))
			render "shared/errors", status: :unprocessable_entity, locals: {errors: @error_manager.get_errors}
		end
	end

	# POST /password/forgot.json
	def forgot
		email = params[:email]
		if email.blank?
			@error_manager.add_error(I18n.t("errors.messages.email_not_present"))
			render "shared/errors", status: :not_found, locals: {errors: @error_manager.get_errors}
		end
		user = User.find_by(email: email)
		if user.present?
			user.generate_password_token!
			PasswordMailer.forgot(user, user.reset_password_token).deliver
			render "shared/success", status: :ok, locals: {message: I18n.t("confirmations.messages.reset_mail_sent")}
		else
			@error_manager.add_error(I18n.t("errors.messages.email_not_present"))
			render "shared/errors", status: :unprocessable_entity, locals: {errors: @error_manager.get_errors}
		end
	end

	# GET /password/reset.json
	def reset
		email = params[:email]
		reset_token = params[:reset_token]
		# Has the user inserted an email?
		if email.blank?
			@error_manager.add_error('Email not present')
			render "shared/errors", status: :not_found, locals: {errors: @error_manager.get_errors}
		else
			# Is the reset token present?
			if reset_token.blank?
				@error_manager.add_error('Reset token not present')
				render "shared/errors", status: :not_found, locals: {errors: @error_manager.get_errors}
			else
				user = User.find_by(reset_password_token: reset_token)
				if user.present? && user.password_token_valid?
					new_password = SecureRandom.hex (rand(6..10))
					if user.reset_password!(new_password)
						PasswordMailer.reset(user, new_password).deliver
						render "shared/success", status: :ok, locals: {message: I18n.t("confirmations.messages.new_password_mail_sent")}
					else
						render json: user.errors, status: :unprocessable_entity
					end
				else
					@error_manager.add_error(I18n.t("errors.messages.invalid_link"))
					render "shared/errors", status: :not_found, locals: {errors: @error_manager.get_errors}
				end
			end
		end
	end

	private

	def set_error_manager
		@error_manager = ErrorManager.new
	end

end
