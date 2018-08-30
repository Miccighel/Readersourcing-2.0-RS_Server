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

end
