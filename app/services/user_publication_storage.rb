require "fileutils"

class UserPublicationStorage

	def initialize(user_id, storage_root: Publication.storage_root)
		@user_id = Integer(user_id)
		raise ArgumentError, "User identifier must be positive" unless @user_id.positive?

		@storage_root = Pathname.new(storage_root).expand_path
	end

	def remove!
		path = user_path
		return false unless path.directory?

		FileUtils.remove_entry_secure(path)
		true
	end

	def user_path
		users_root = @storage_root.join("user").cleanpath
		path = users_root.join(@user_id.to_s).cleanpath
		raise "Invalid publication storage path" unless path.dirname == users_root

		path
	end

end
