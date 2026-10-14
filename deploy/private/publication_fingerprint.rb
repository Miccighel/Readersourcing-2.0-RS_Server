require "digest"
require "json"

class PrivatePublicationFingerprint

  class Error < StandardError; end

  def initialize(directory)
    @directory = File.expand_path(directory)
  end

  def calculate
    @entries, @files, @bytes = [], 0, 0
    raise Error, "Publication storage must be a directory" unless File.directory?(@directory)
    visit(@directory, ".")
    {
      "sha256" => Digest::SHA256.hexdigest(JSON.generate(@entries)),
      "files" => @files, "directories" => @entries.length - @files, "bytes" => @bytes,
      "scope" => "All regular files and directories, including hidden entries; ownership and permissions; no timestamps"
    }
  end

  private

  def visit(path, relative)
    stat = File.lstat(path)
    entry = {"path" => relative, "mode" => stat.mode & 0o7777, "uid" => stat.uid, "gid" => stat.gid}
    if stat.directory?
      entry["type"] = "directory"
      @entries << entry
      Dir.children(path).sort.each { |name| visit(File.join(path, name), relative == "." ? name : "#{relative}/#{name}") }
    elsif stat.file?
      entry.merge!("type" => "file", "size" => stat.size, "sha256" => Digest::SHA256.file(path).hexdigest)
      @entries << entry
      @files += 1
      @bytes += stat.size
    else
      raise Error, "Publication storage contains a symbolic link or unsupported entry"
    end
  end

end

if $PROGRAM_NAME == __FILE__
  begin
    raise PrivatePublicationFingerprint::Error, "Expected one publication directory" unless ARGV.length == 1
    puts JSON.pretty_generate(PrivatePublicationFingerprint.new(ARGV.fetch(0)).calculate)
  rescue StandardError => error
    warn "Publication fingerprint failed (#{error.class}); private paths were not printed"
    exit 1
  end
end
