class AuthenticationToken < ApplicationRecord

	LIFETIME = 168.hours

	belongs_to :user

	before_validation :assign_jti, on: :create

	validates :jti, presence: true, uniqueness: true
	validates :expires_at, presence: true

	def self.issue_for(user)
		user.authentication_tokens.where("expires_at <= ?", Time.current).delete_all
		user.authentication_tokens.create!(expires_at: LIFETIME.from_now)
	end

	def active?
		expires_at.future?
	end

	private

	def assign_jti
		self.jti ||= SecureRandom.uuid
	end

end
