class User < ApplicationRecord

	has_many :ratings, dependent: :destroy

end
