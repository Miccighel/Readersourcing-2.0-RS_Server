class PaperRatingReference

	CIPHER = "aes-256-gcm".freeze
	KEY_SALT = "paper-rating-reference".freeze
	PURPOSE = "paper-rating-reference".freeze
	VERSION = 1

	class << self

		def issue(user:, publication:)
			encryptor.encrypt_and_sign(
				{
					version: VERSION,
					user_id: user.id,
					publication_id: publication.id
				},
				purpose: PURPOSE
			)
		end

		def resolve(reference, publication:)
			payload = decrypt(reference)
			return resolve_legacy(reference) unless payload
			return unless payload["version"] == VERSION
			return unless Integer(payload["publication_id"], exception: false) == publication.id

			User.find_by(id: payload["user_id"])
		end

		private

		def decrypt(reference)
			encryptor.decrypt_and_verify(reference.to_s, purpose: PURPOSE)
		rescue ActiveSupport::MessageEncryptor::InvalidMessage, ArgumentError, TypeError
			nil
		end

		def encryptor
			key_length = ActiveSupport::MessageEncryptor.key_len(CIPHER)
			key = Rails.application.key_generator.generate_key(KEY_SALT, key_length)
			ActiveSupport::MessageEncryptor.new(key, cipher: CIPHER, serializer: JSON)
		end

		def resolve_legacy(reference)
			salt, encrypted_token = reference.to_s.split("!!!!!", 2)
			return if salt.blank? || encrypted_token.blank?

			key_length = ActiveSupport::MessageEncryptor.key_len
			key = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(salt, key_length)
			auth_token = ActiveSupport::MessageEncryptor.new(key).decrypt_and_verify(encrypted_token)
			payload = JsonWebToken.decode(auth_token)
			User.find_by(id: payload[:user_id]) if payload
		rescue ActiveSupport::MessageEncryptor::InvalidMessage, ArgumentError, TypeError
			nil
		end

	end

end
