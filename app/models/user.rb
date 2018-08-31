class User < ApplicationRecord

	has_many :ratings, dependent: :destroy

	validates :email, presence: true, length: {maximum: 255}, format: {with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i}, uniqueness: {case_sensitive: false}
	validates :orcid,  length: {maximum: 19}, format: {with: /[0-9]{4}-[0-9]{4}-[0-9]{4}-([0-9]{3}X|[0-9]{4})/}, uniqueness: true
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

	private

	def generate_token
		SecureRandom.hex(10)
	end

end
