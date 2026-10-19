require "json"
require_relative "image_acceptance_configuration"

module ImageAcceptanceDiagnostic
  FILES = %w[base/trial.json baseline.json options.json compose.json resolved.json].freeze
  GUARDS = {
    "Unsafe acceptance identity" => "project_identity",
    "Unpinned acceptance image" => "image_identity",
    "Unsafe acceptance directory" => "directory_identity",
    "Unexpected acceptance services" => "service_inventory",
    "Unexpected baseline image" => "baseline_image",
    "Unsafe acceptance runtime" => "runtime_restrictions",
    "Unexpected acceptance input" => "unexpected_service_option",
    "Missing acceptance restrictions" => "missing_security_restriction",
    "Unexpected acceptance origin" => "public_origin",
    "Unexpected acceptance bind" => "bind_mount",
    "Unexpected volume target" => "volume_target",
    "Unexpected acceptance storage" => "mount_type",
    "Unexpected acceptance volume" => "volume_inventory",
    "Incomplete acceptance binds" => "bind_inventory",
    "Unexpected setup command" => "migration_command",
    "Acceptance network is not isolated" => "network_isolation",
    "Unexpected volume definitions" => "volume_definitions",
    "Shared acceptance volume" => "shared_volume",
    "Incomplete isolated acceptance input" => "input_schema",
    "Resolved acceptance configuration differs" => "compose_round_trip"
  }.freeze

  def self.categories(log)
    {
      "permission_denied" => /Permission denied|EACCES/i,
      "missing_local_image" => /No such image|Unable to find image|pull access denied/i,
      "runtime_configuration" => /unknown or invalid runtime|nvidia-container|OCI runtime create failed/i,
      "memory_limit" => /out of memory|cannot allocate memory/i,
      "missing_ruby_library" => /cannot load such file|LoadError/,
      "compose_validation" => /validating .*compose|additional propert|unknown flag|unknown shorthand/i,
      "definition_guard" => /Isolated image definition failed/,
      "read_only_filesystem" => /Read-only file system|EROFS/,
      "no_disk_space" => /No space left on device|ENOSPC/
    }.filter_map { |category, expression| category if expression.match?(log) }.sort
  end

  def self.guard_category(message)
    GUARDS.fetch(message, "unclassified_input_error")
  end

  def self.report(directory)
    present = FILES.to_h { |name| [name, File.file?(File.join(directory, name)) && !File.symlink?(File.join(directory, name))] }
    log_path = File.join(directory, "commands.log")
    raise "Unsupported diagnostic log" if File.symlink?(log_path) || !File.file?(log_path) || File.size(log_path) > 4 * 1024 * 1024
    result = {"status" => "read_only_acceptance_diagnostic", "files_or_services_changed" => false,
      "private_values_or_log_contents_displayed" => false, "files_present" => present,
      "known_error_categories" => categories(File.binread(log_path))}
    if present.fetch("options.json") && present.fetch("baseline.json")
      options = JSON.parse(File.read(File.join(directory, "options.json")))
      raise "Unexpected diagnostic inputs" unless options.fetch("baseline") == File.join(directory, "baseline.json") &&
        options.fetch("destination") == File.join(directory, "compose.json") && options.fetch("resolved") == File.join(directory, "resolved.json")
      checker = ImageAcceptanceConfiguration.new(**options.fetch("configuration").transform_keys(&:to_sym)
        .merge(baseline: JSON.parse(File.read(File.join(directory, "baseline.json")))))
      begin
        checker.definition
        result["definition_guard"] = "passed"
        if present.fetch("resolved.json")
          checker.validate!(JSON.parse(File.read(File.join(directory, "resolved.json"))))
          result["compose_round_trip"] = "passed"
        end
      rescue ImageAcceptanceConfiguration::Error => error
        result["definition_guard"] = guard_category(error.message)
      end
    end
    result
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    raise "Expected a protected acceptance directory" unless Process.uid.zero? && ARGV.length == 1 &&
      ARGV[0].match?(/\A\/var\/tmp\/rs-server-image-acceptance\.[a-z0-9_]{8}\z/)
    directory = ARGV[0]
    stat = File.lstat(directory)
    raise "Unexpected diagnostic ownership" unless stat.directory? && !stat.symlink? && stat.uid.zero? && (stat.mode & 0o777) == 0o700
    puts JSON.pretty_generate(ImageAcceptanceDiagnostic.report(directory))
  rescue StandardError
    warn "Read only acceptance diagnosis not confirmed; private values were not displayed."
    exit 1
  end
end
