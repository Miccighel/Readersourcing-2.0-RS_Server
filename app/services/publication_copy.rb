require "json"

class PublicationCopy

  GENERATION_FORMAT = /\A[0-9a-f]{32}\z/
  MANIFEST_LIMIT = 4096

  attr_reader :generation, :directory, :root, :filename

  def initialize(publication:, user:, generation:, filename:, directory: nil)
    @root = self.class.root_for(publication, user)
    raise ArgumentError, "Invalid publication copy" unless generation.nil? || GENERATION_FORMAT.match?(generation.to_s)
    raise ArgumentError, "Invalid PDF filename" unless self.class.safe_filename?(filename)

    @generation = generation
    @filename = filename
    @directory = directory || @root.join("generations", generation)
  end

  def self.root_for(publication, user)
    identifiers = [user.id, publication.id].map { |id| Integer(id) }
    raise ArgumentError, "Identifiers must be positive" unless identifiers.all?(&:positive?)

    Publication.storage_root.join("user", identifiers[0].to_s, "publication", "pdf", identifiers[1].to_s)
  end

  def self.current(publication:, user:)
    pointer = root_for(publication, user).join("current")
    return legacy(publication: publication, user: user) unless pointer.file?

    generation = pointer.read(MANIFEST_LIMIT).strip
    find(publication: publication, user: user, generation: generation)
  end

  def self.find(publication:, user:, generation:)
    return unless generation.is_a?(String) && GENERATION_FORMAT.match?(generation)

    directory = root_for(publication, user).join("generations", generation)
    metadata = JSON.parse(directory.join("copy.json").read(MANIFEST_LIMIT))
    return unless metadata.is_a?(Hash) && metadata["version"] == 1

    new(publication: publication, user: user, generation: generation, filename: metadata.fetch("filename"))
  rescue Errno::ENOENT, JSON::ParserError, KeyError, ArgumentError
    nil
  end

  def self.legacy(publication:, user:, filename: nil, variant: nil)
    relative = publication.pdf_storage_path.to_s
    directory = if /\Apublication\/pdf\/[a-zA-Z0-9_-]+\/?\z/.match?(relative)
      Publication.storage_root.join("user", user.id.to_s, relative)
    else
      root_for(publication, user)
    end
    original = "#{Publication.safe_pdf_stem(publication.pdf_name)}.pdf"
    suffix = "#{Settings.rs_pdf_link_suffix}.pdf"

    if filename
      return unless safe_filename?(filename)
      original = variant.to_s == "annotated" ? "#{filename.delete_suffix(suffix)}.pdf" : filename
    elsif directory.directory?
      names = directory.children.select { |path| path.file? && path.basename.to_s.end_with?(suffix) }
      expected = "#{Publication.safe_pdf_stem(original)}#{suffix}"
      if !directory.join(expected).file? && names.one?
        original = "#{names.first.basename.to_s.delete_suffix(suffix)}.pdf"
      end
    end

    new(publication: publication, user: user, generation: nil, filename: original, directory: directory)
  end

  def self.safe_filename?(filename)
    filename.is_a?(String) && filename == "#{Publication.safe_pdf_stem(filename)}.pdf"
  end

  def name(variant)
    case variant.to_s
    when "original" then filename
    when "annotated" then "#{Publication.safe_pdf_stem(filename)}#{Settings.rs_pdf_link_suffix}.pdf"
    else raise ArgumentError, "Unsupported PDF variant"
    end
  end

  def path(variant)
    directory.join(name(variant))
  end

  def available?(variant)
    path(variant).file?
  end

  def logical_path(variant)
    path(variant).relative_path_from(Publication.storage_root).to_s if available?(variant)
  end

  def logical_directory
    "#{directory.relative_path_from(Publication.storage_root)}/" if available?("annotated") || available?("original")
  end

  def retain_until(time)
    return unless generation
    deadline = time.to_f.ceil + PublicationCopyStore::RETIREMENT_GRACE.to_i

    PublicationCopyStore.new(root).synchronize do
      lease = directory.join("retain-until")
      current = lease.file? ? Integer(lease.read(MANIFEST_LIMIT), exception: false) : 0
      raise "Invalid publication copy lease" unless current
      if current < deadline
        PublicationCopyStore.atomic_write(lease, deadline.to_s)
      end
    end
  end

end
