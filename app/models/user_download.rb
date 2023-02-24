class UserDownload < ApplicationRecord
	belongs_to :user, optional: true
	belongs_to :layer
end
