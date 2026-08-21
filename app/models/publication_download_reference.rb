class PublicationDownloadReference

	PURPOSE = "publication-download".freeze
	KEY_SALT = "publication-download-reference".freeze
	VERSION = 1
	DEFAULT_TTL = 5.minutes
	VARIANTS = %w[original annotated].freeze

	class << self

		def issue(user:, publication:, variant:, filename:, expires_in: ttl)
			variant = normalize_variant(variant)
			verifier.generate(
				{
					version: VERSION,
					user_id: user.id,
					publication_id: publication.id,
					variant: variant,
					filename: filename
				},
				expires_in: expires_in,
				purpose: PURPOSE
			)
		end

		def resolve(reference, publication:, variant:, filename:)
			payload = verifier.verified(reference.to_s, purpose: PURPOSE)
			return unless payload.is_a?(Hash)
			payload = payload.with_indifferent_access
			return unless payload["version"] == VERSION
			return unless Integer(payload["publication_id"], exception: false) == publication.id
			return unless payload["variant"] == normalize_variant(variant)
			return unless ActiveSupport::SecurityUtils.secure_compare(payload["filename"].to_s, filename.to_s)

			User.find_by(id: payload["user_id"])
		rescue ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError, TypeError
			nil
		end

		def ttl
			seconds = Integer(ENV.fetch("RS_PDF_DOWNLOAD_URL_TTL", DEFAULT_TTL.to_i), exception: false)
			seconds&.positive? ? seconds.seconds : DEFAULT_TTL
		end

		private

		def normalize_variant(variant)
			value = variant.to_s
			raise ArgumentError, "Unsupported PDF variant" unless VARIANTS.include?(value)

			value
		end

		def verifier
			key = Rails.application.key_generator.generate_key(KEY_SALT)
			ActiveSupport::MessageVerifier.new(
				key,
				digest: "SHA256",
				serializer: JSON,
				url_safe: true
			)
		end

	end

end
