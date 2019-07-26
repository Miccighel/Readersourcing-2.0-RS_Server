class User < ApplicationRecord

	has_many :ratings, dependent: :destroy

	validates :email, presence: true, length: {maximum: 255}, format: {with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i}, uniqueness: {case_sensitive: false}
	validates :orcid, length: {maximum: 19}, format: {with: /[0-9]{4}-[0-9]{4}-[0-9]{4}-([0-9]{3}X|[0-9]{4})/}, allow_blank: true, uniqueness: true

	# PASSWORD HANDLING

	has_secure_password

	def password
		@password ||= BCrypt::Password.new(password_digest)
	end

	def password=(new_password)
		@password = BCrypt::Password.create(new_password)
		self.password_digest = @password
	end

	def generate_password_token!
		self.reset_password_token = generate_token
		self.reset_password_sent_at = Time.now.utc
		save!
	end

	def password_token_valid?
		(self.reset_password_sent_at + 4.hours) > Time.now.utc
	end

	def reset_password!(password)
		self.reset_password_token = nil
		self.password = password
		save!
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

	def generate_token
		SecureRandom.urlsafe_base64.to_s
	end

end
