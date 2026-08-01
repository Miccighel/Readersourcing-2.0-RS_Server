require "digest"

class User < ApplicationRecord

	has_many :ratings, dependent: :destroy
	has_many :authentication_tokens, dependent: :destroy

	after_update :revoke_authentication_tokens_after_password_change, if: :saved_change_to_password_digest?

	validates :email, presence: true, length: {maximum: 255}, format: {with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i}, uniqueness: {case_sensitive: false}
	validates :orcid, length: {maximum: 19}, format: {with: /[0-9]{4}-[0-9]{4}-[0-9]{4}-([0-9]{3}X|[0-9]{4})/}, allow_blank: true, uniqueness: true

	# PASSWORD HANDLING

	has_secure_password
	validates :password, length: {minimum: 6}, allow_nil: true

	def self.find_by_password_reset_token(token)
		return if token.blank?

		find_by(reset_password_token: password_token_digest(token))
	end

	def self.password_token_digest(token)
		Digest::SHA256.hexdigest(token)
	end

	def generate_password_token!
		token = generate_token
		self.reset_password_token = self.class.password_token_digest(token)
		self.reset_password_sent_at = Time.now.utc
		save!
		token
	end

	def password_token_valid?
		reset_password_sent_at.present? && (reset_password_sent_at + 4.hours) > Time.now.utc
	end

	def reset_password!(token, password, password_confirmation)
		with_lock do
			return false unless password_token_matches?(token)

			self.reset_password_token = nil
			self.reset_password_sent_at = nil
			self.password = password
			self.password_confirmation = password_confirmation
			save
		end
	end

	# EMAIL HANDLING

	def generate_confirm_token
		if self.confirm_token.blank?
			self.confirm_token = generate_token
		end
	end

	def activate_email
		self.email_confirmed = true
		self.confirm_token = nil
		save!(:validate => false)
	end

	# QUERIES

	def is_subscribed
		self.subscribe
	end

	def given_rating(publication)
		Rating.where(user_id: self.id, publication_id: publication.id).first
	end

	def given_ratings
		Rating.where(user_id: self.id).all
	end

	# PRETTY PRINTING

	def orcid_url
		if self.orcid.present?
			host = URI::HTTPS.build(:host => "orcid.org")
			"#{host}/#{self.orcid}"
		end
	end

	def pretty_score_rsm
		"#{(self.score*100).round(2).prettify}/100"
	end

	def pretty_score_trm
		"#{(self.bonus*100).round(2).prettify}/100"
	end

	private

	def revoke_authentication_tokens_after_password_change
		authentication_tokens.delete_all
	end

	def password_token_matches?(token)
		return false if token.blank? || reset_password_token.blank? || !password_token_valid?

		supplied_digest = self.class.password_token_digest(token)
		ActiveSupport::SecurityUtils.secure_compare(reset_password_token, supplied_digest)
	end

	def generate_token
		SecureRandom.urlsafe_base64.to_s
	end

end
