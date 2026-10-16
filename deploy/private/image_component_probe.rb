require "json"
require "open3"
require "pathname"

class ImageComponentProbe

  PACKAGES = %w[libtinfo6 ncurses-base ncurses-bin libsystemd0 libudev1 libacl1 bsdutils libblkid1
    liblastlog2-2 libmount1 libsmartcols1 libuuid1 login mount util-linux perl-base].freeze
  COMPONENTS = {
    "infocmp" => %w[/usr/bin/infocmp /bin/infocmp],
    "systemd_homed" => %w[/usr/lib/systemd/systemd-homed /lib/systemd/systemd-homed],
    "systemd_homework" => %w[/usr/lib/systemd/systemd-homework /lib/systemd/systemd-homework],
    "mount" => %w[/usr/bin/mount /bin/mount],
    "nsenter" => %w[/usr/bin/nsenter /bin/nsenter],
    "libacl" => %w[/usr/lib/*/libacl.so* /lib/*/libacl.so*],
    "perl_archive_tar" => %w[/usr/share/perl/*/Archive/Tar.pm /usr/share/perl5/Archive/Tar.pm
      /usr/lib/*/perl/*/Archive/Tar.pm /usr/lib/*/perl-base/Archive/Tar.pm]
  }.freeze

  def initialize(root: "/", package_output: nil, mode_reader: ->(path) { File.stat(path).mode })
    @root = Pathname(root)
    @package_output = package_output
    @mode_reader = mode_reader
  end

  def report
    output = @package_output || installed_packages
    packages = {}
    output.each_line do |line|
      name, version = line.chomp.split("\t", 2)
      name = name.to_s.split(":").first
      next unless PACKAGES.include?(name)
      raise "Invalid package record" unless version && version.match?(/\A[0-9A-Za-z.+:~\-]+\z/) && !packages.key?(name)
      packages[name] = version
    end
    raise "Package inventory unavailable" if packages.empty?
    components = COMPONENTS.to_h do |name, patterns|
      paths = patterns.flat_map { |pattern| Dir.glob(@root.join(pattern.delete_prefix("/")).to_s) }
        .select { |path| File.file?(path) }.uniq
      [name, {"present_at_checked_locations" => paths.any?,
        "setuid_or_setgid_at_checked_locations" => paths.any? { |path| @mode_reader.call(path) & 0o6000 != 0 }}]
    end
    {"status" => "image_component_probe_completed", "packages" => packages.sort.to_h,
      "components" => components, "effective_uid" => Process.uid,
      "scope" => "Selected package versions and known component locations in the exact image; no component execution or exploit",
      "fresh_vulnerability_scan" => false, "complete_reachability_assessment" => false,
      "advisories_excluded" => false, "security_approval" => false,
      "application_or_backup_volumes_mounted" => false, "network_enabled" => false}
  end

  private

  def installed_packages
    output, _errors, status = Open3.capture3("dpkg-query", "-W", '-f=${binary:Package}\t${Version}\n')
    raise "Package query failed" unless status.success?
    output
  end

end

if $PROGRAM_NAME == __FILE__
  begin
    raise "Unexpected arguments" unless ARGV.empty?
    raise "Expected unprivileged probe" if Process.uid.zero?
    puts JSON.pretty_generate(ImageComponentProbe.new.report)
  rescue StandardError
    warn "Image component probe failed; no private values were displayed"
    exit 1
  end
end
