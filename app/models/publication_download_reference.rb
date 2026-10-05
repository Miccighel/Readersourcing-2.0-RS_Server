class PublicationDownloadReference

	PURPOSE = "publication-download".freeze
	KEY_SALT = "publication-download-reference".freeze
	VERSION = 2
	DEFAULT_TTL = 5.minutes
	VARIANTS = %w[original annotated].freeze

	class << self

		def issue(user:, publication:, variant:, filename:, generation: nil, expires_in: ttl)
			variant = normalize_variant(variant)
			if generation
				copy = PublicationCopy.find(publication: publication, user: user, generation: generation)
				raise ArgumentError, "Invalid publication copy" unless copy&.available?(variant) && copy.name(variant) == filename
				copy.retain_until(Time.current + expires_in)
			end
			verifier.generate(
				{
					version: generation ? VERSION : 1,
					user_id: user.id,
					publication_id: publication.id,
					variant: variant,
					filename: filename,
					generation: generation
				},
				expires_in: expires_in,
				purpose: PURPOSE
			)
		end

		def resolve(reference, publication:, variant:, filename:)
			payload = verified_payload(reference, publication: publication, variant: variant, filename: filename)
			User.find_by(id: payload["user_id"]) if payload
		end

		def resolve_copy(reference, publication:, variant:, filename:)
			payload = verified_payload(reference, publication: publication, variant: variant, filename: filename)
			return unless payload
			user = User.find_by(id: payload["user_id"])
			return unless user

			copy = if payload["version"] == VERSION
				PublicationCopy.find(publication: publication, user: user, generation: payload["generation"])
			else
				PublicationCopy.legacy(publication: publication, user: user, filename: filename, variant: variant)
			end
			copy if copy&.available?(variant) && copy.name(variant) == filename
		end

		def ttl
			seconds = Integer(ENV.fetch("RS_PDF_DOWNLOAD_URL_TTL", DEFAULT_TTL.to_i), exception: false)
			seconds&.positive? ? seconds.seconds : DEFAULT_TTL
		end

		private

		def verified_payload(reference, publication:, variant:, filename:)
			payload = verifier.verified(reference.to_s, purpose: PURPOSE)
			return unless payload.is_a?(Hash)
			payload = payload.with_indifferent_access
			return unless [1, VERSION].include?(payload["version"])
			return if payload["version"] == VERSION && !PublicationCopy::GENERATION_FORMAT.match?(payload["generation"].to_s)
			return unless Integer(payload["publication_id"], exception: false) == publication.id
			return unless payload["variant"] == normalize_variant(variant)
			return unless ActiveSupport::SecurityUtils.secure_compare(payload["filename"].to_s, filename.to_s)

			payload
		rescue ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError, TypeError
			nil
		end

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
