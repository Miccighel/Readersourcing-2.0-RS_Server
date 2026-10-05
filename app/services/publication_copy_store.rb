require "tmpdir"
require "fileutils"

class PublicationCopyStore

  RETIREMENT_GRACE = 60.seconds

  def initialize(root)
    @root = Pathname.new(root)
  end

  def prepare(publication:, user:, filename:, transaction:)
    raise ArgumentError, "Invalid publication storage root" unless @root == PublicationCopy.root_for(publication, user)
    FileUtils.mkdir_p(@root.join("generations"), mode: 0700)
    generation = SecureRandom.hex(16)
    final_path = @root.join("generations", generation)
    copy = nil

    staging = Pathname.new(Dir.mktmpdir("rs-copy-", @root.to_s))
    begin
      staged = PublicationCopy.new(
        publication: publication, user: user, generation: generation,
        filename: "#{Publication.safe_pdf_stem(filename)}.pdf", directory: staging
      )
      yield staged
      raise "Publication copy is incomplete" unless staged.available?("original") && staged.available?("annotated")

      self.class.atomic_write(staged.directory.join("copy.json"), JSON.generate(version: 1, filename: staged.filename))
      File.rename(staging, final_path)
      copy = PublicationCopy.new(publication: publication, user: user, generation: generation, filename: staged.filename)
    ensure
      FileUtils.remove_entry_secure(staging) if staging.directory?
    end

    transaction.after_rollback { discard(copy) }
    transaction.after_commit { publish(copy) }
    copy
  rescue StandardError
    discard(copy) if copy
    raise
  end

  def synchronize
    File.open(@root.join(".lock"), File::RDWR | File::CREAT, 0600) do |lock|
      lock.flock(File::LOCK_EX)
      yield
    ensure
      lock.flock(File::LOCK_UN) if lock
    end
  end

  def self.atomic_write(path, contents)
    temporary = Pathname.new("#{path}.#{SecureRandom.hex(8)}.tmp")
    File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, 0600) { |file| file.write(contents) }
    File.rename(temporary, path)
  ensure
    File.delete(temporary) if temporary&.file?
  end

  private

  def publish(copy)
    synchronize do
      pointer = @root.join("current")
      previous = pointer.file? ? pointer.read(PublicationCopy::MANIFEST_LIMIT).strip : nil
      if previous && PublicationCopy::GENERATION_FORMAT.match?(previous)
        previous_path = @root.join("generations", previous)
        if previous_path.directory?
          self.class.atomic_write(previous_path.join("retired-until"), (Time.current + RETIREMENT_GRACE).to_i.to_s)
        end
      end
      self.class.atomic_write(pointer, copy.generation)
      remove_expired_generations(except: [copy.generation, previous])
    end
  end

  def discard(copy)
    return unless copy.directory.directory?

    FileUtils.remove_entry_secure(copy.directory)
  end

  def remove_expired_generations(except:)
    @root.join("generations").children.each do |path|
      next unless PublicationCopy::GENERATION_FORMAT.match?(path.basename.to_s)
      next if except.include?(path.basename.to_s) || path.symlink? || !path.directory?
      retired = path.join("retired-until")
      next unless retired.file?

      retirement = Integer(retired.read(PublicationCopy::MANIFEST_LIMIT), exception: false)
      lease = path.join("retain-until")
      expiration = lease.file? ? Integer(lease.read(PublicationCopy::MANIFEST_LIMIT), exception: false) : 0
      next unless retirement && expiration && [retirement, expiration].max <= Time.current.to_i

      FileUtils.remove_entry_secure(path)
    end
  rescue SystemCallError => error
    Rails.logger.warn("Publication copy cleanup failed (#{error.class.name})")
  end

end
