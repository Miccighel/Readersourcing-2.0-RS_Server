class User < ApplicationRecord

	has_many :ratings, dependent: :destroy

	has_secure_password

end
