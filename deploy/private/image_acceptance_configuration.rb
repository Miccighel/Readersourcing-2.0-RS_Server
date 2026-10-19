require "json"
require_relative "prepare"

class ImageAcceptanceConfiguration

  class Error < StandardError; end
  SERVICES = %w[database mailpit rs_server_setup rs_server_webapp].freeze

  def initialize(baseline:, project:, active_project:, base_directory:, application_image:, database_image:, mailpit_image:)
    @baseline, @project, @active_project, @base = baseline, project, active_project, base_directory
    @images = {"rs_server_setup" => application_image, "rs_server_webapp" => application_image,
      "database" => database_image, "mailpit" => mailpit_image}
  end

  def definition
    validate_source!
    result = JSON.parse(JSON.generate(@baseline))
    result.delete_if { |key, _| key.start_with?("x-") }
    result.fetch("services").delete("access")
    result["networks"] = {"default" => result.fetch("networks").fetch("default")}
    result.fetch("services").each do |name, service|
      service["image"] = @images.fetch(name)
      service["pull_policy"] = "never"
    end
    result.fetch("services").fetch("rs_server_webapp").fetch("volumes") << {
      "type" => "bind", "source" => File.join(@base, "fixtures/Reader.pdf"),
      "target" => "/acceptance/Reader.pdf", "read_only" => true, "bind" => {"create_host_path" => false}}
    result
  rescue KeyError, TypeError, NoMethodError
    raise Error, "Incomplete isolated acceptance input"
  end

  def validate!(resolved)
    raise Error, "Resolved acceptance configuration differs" unless comparable(resolved) == comparable(definition)
    {"status" => "isolated_image_definition_verified", "published_ports" => false,
      "active_volumes_reused" => false, "images_pinned" => true}
  end

  private

  # Compose 2.39 omits this false field in config output; the input keeps it explicit.
  # Restrict the equivalence to the one public fixture bind. True remains a difference.
  def comparable(configuration)
    result = JSON.parse(JSON.generate(configuration))
    mounts = result.fetch("services").fetch("rs_server_webapp").fetch("volumes")
    mounts.each do |mount|
      next unless mount["type"] == "bind" && mount["source"] == File.join(@base, "fixtures/Reader.pdf") &&
        mount["target"] == "/acceptance/Reader.pdf" && mount["read_only"] == true && mount["bind"].is_a?(Hash)
      mount["bind"].delete("create_host_path") if mount["bind"]["create_host_path"] == false
    end
    result
  rescue KeyError, TypeError, NoMethodError
    raise Error, "Incomplete isolated acceptance input"
  end

  def validate_source!
    raise Error, "Unsafe acceptance identity" unless @project.match?(/\Ars-private-[0-9a-f]{12}\z/) &&
      @project != @active_project && @baseline.fetch("name") == @project
    raise Error, "Unpinned acceptance image" unless @images.values.all? { |image| image.match?(/\Asha256:[0-9a-f]{64}\z/) }
    raise Error, "Unsafe acceptance directory" unless @base.start_with?("/") && File.expand_path(@base) == @base && @base.end_with?("/base")
    services = @baseline.fetch("services")
    raise Error, "Unexpected acceptance services" unless services.keys.sort == (SERVICES + ["access"]).sort
    expected_images = {"database" => "postgres:17", "mailpit" => "axllent/mailpit:v1.31.5",
      "rs_server_setup" => PrivateTrial::APPLICATION_IMAGE, "rs_server_webapp" => PrivateTrial::APPLICATION_IMAGE}
    SERVICES.each do |name|
      service = services.fetch(name)
      raise Error, "Unexpected baseline image" unless service.fetch("image") == expected_images.fetch(name)
      raise Error, "Unsafe acceptance runtime" unless service.fetch("runtime") == "runc" && service.fetch("restart") == "no" &&
        !service.fetch("privileged", false) && (service.fetch("networks").is_a?(Hash) ? service.fetch("networks").keys : service.fetch("networks")) == ["default"]
      raise Error, "Unexpected acceptance input" if %w[ports build env_file extends devices gpus network_mode pid ipc volumes_from container_name].any? { |key| service.key?(key) }
      if name != "database"
        raise Error, "Missing acceptance restrictions" unless service.fetch("read_only") == true && service.fetch("cap_drop") == ["ALL"] &&
          service.fetch("security_opt").any? { |value| %w[no-new-privileges:true no-new-privileges].include?(value) }
      end
      if name.start_with?("rs_server_")
        environment = service.fetch("environment")
        raise Error, "Unexpected acceptance origin" unless environment.fetch("PUBLIC_BASE_URL") == "http://127.0.0.1:33030" &&
          environment.fetch("RS_PDF_ALLOW_PRIVATE_NETWORKS") == "false"
      end
      names, bindings = [], []
      service.fetch("volumes", []).each do |mount|
        case mount.fetch("type")
        when "bind"
          filename = File.basename(mount.fetch("source"))
          allowed = name == "mailpit" ? %w[smtp.crt smtp.key smtp.auth ui.auth] : (name == "database" ? [] : ["smtp.crt"])
          raise Error, "Unexpected acceptance bind" unless allowed.include?(filename) &&
            mount.fetch("source") == File.join(@base, "runtime", filename) && mount.fetch("target") == "/trial/#{filename}" && mount.fetch("read_only") == true
          bindings << filename
        when "volume"
          names << mount.fetch("source")
          target = name == "database" ? "/var/lib/postgresql/data" : "/rs_server/storage/publications/user"
          raise Error, "Unexpected volume target" unless mount.fetch("target") == target
        else
          raise Error, "Unexpected acceptance storage"
        end
      end
      expected = name == "database" ? ["database"] : (name.start_with?("rs_server_") ? ["publications"] : [])
      raise Error, "Unexpected acceptance volume" unless names.sort == expected
      expected_bindings = name == "mailpit" ? %w[smtp.auth smtp.crt smtp.key ui.auth] : (name == "database" ? [] : ["smtp.crt"])
      raise Error, "Incomplete acceptance binds" unless bindings.sort == expected_bindings
    end
    raise Error, "Unexpected setup command" unless services.fetch("rs_server_setup").fetch("command") == ["./bin/rails", "db:migrate"]
    network = @baseline.fetch("networks").fetch("default")
    raise Error, "Acceptance network is not isolated" unless network.fetch("name") == "#{@project}_default" && network.fetch("internal") == true &&
      network.fetch("driver") == "bridge" && network.fetch("driver_opts").fetch("com.docker.network.bridge.gateway_mode_ipv4") == "isolated" && !network.fetch("external", false)
    volumes = @baseline.fetch("volumes")
    raise Error, "Unexpected volume definitions" unless volumes.keys.sort == %w[database publications]
    volumes.each do |name, definition|
      raise Error, "Shared acceptance volume" unless definition.fetch("name") == "#{@project}_#{name}" &&
        !definition.fetch("external", false) && !definition.key?("driver_opts")
    end
  end

end

if $PROGRAM_NAME == __FILE__
  begin
    raise ImageAcceptanceConfiguration::Error, "Expected acceptance options and operation" unless ARGV.length == 2
    options = JSON.parse(File.read(ARGV[0]))
    checker = ImageAcceptanceConfiguration.new(**options.fetch("configuration").transform_keys(&:to_sym)
      .merge(baseline: JSON.parse(File.read(options.fetch("baseline")))))
    case ARGV[1]
    when "prepare"
      File.write(options.fetch("destination"), JSON.pretty_generate(checker.definition) + "\n", mode: "wx", perm: 0o600)
    when "check"
      puts JSON.generate(checker.validate!(JSON.parse(File.read(options.fetch("resolved")))))
    else
      raise ImageAcceptanceConfiguration::Error, "Unknown acceptance operation"
    end
  rescue StandardError
    warn "Isolated image definition failed; private values were not displayed"
    exit 1
  end
end
