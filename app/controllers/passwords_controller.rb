class PasswordsController < ApplicationController

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
				render partial: "shared/success", status: :ok, locals: {message: I18n.t("confirmations.messages.password_update_successful")}
			else
				render json: current_user.errors, status: :unprocessable_entity
			end
		else
			@error_manager.add_error(I18n.t("errors.messages.password_does_not_match"))
			render partial: "shared/errors", status: :unprocessable_entity, locals: {errors: @error_manager.get_errors}
		end
	end

	# POST /password/forgot.json
	def forgot
		email = params[:email]
		if email.blank?
			@error_manager.add_error('Email not present')
			render partial: "shared/errors", status: :not_found, locals: {errors: @error_manager.get_errors}
		end
		user = User.find_by(email: email)
		if user.present?
			user.generate_password_token!
			PasswordMailer.forgot(user, user.reset_password_token).deliver
			render partial: "shared/success", status: :ok, locals: {message: "Mail per il reset della password inviata correttamente."}
		else
			@error_manager.add_error('Email address not found. Please check and try again.')
			render partial: "shared/errors", status: :unprocessable_entity, locals: {errors: @error_manager.get_errors}
		end
	end

	# GET /password/reset.json
	def reset
		email = params[:email]
		reset_token = params[:reset_token]
		if email.blank?
			@error_manager.add_error('Email not present')
			render partial: "shared/errors", status: :not_found, locals: {errors: @error_manager.get_errors}
		end
		if reset_token.blank?
			@error_manager.add_error('Reset token not present')
			render partial: "shared/errors", status: :not_found, locals: {errors: @error_manager.get_errors}
		end
		user = User.find_by(reset_password_token: reset_token)
		if user.present? && user.password_token_valid?
			new_password = SecureRandom.hex (rand(6..10))
			puts new_password
			if user.reset_password!(new_password)
				PasswordMailer.reset(user, new_password).deliver
				render partial: "shared/success", status: :ok, locals: {message: "Mail contenente nuova password inviata correttamente."}
			else
				render json: user.errors, status: :unprocessable_entity
			end
		else
			render json: {error: ['Link not valid or expired. Try generating a new link.']}, status: :not_found
		end
	end

	private

	def set_error_manager
		@error_manager = ErrorManager.new
	end

end
