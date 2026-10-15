require "json"

module DeploymentLayoutFixtures
  PROJECT = "rs-private-0123456789ab"
  IMAGE = "sha256:#{'a' * 64}"
  REVISION = "b" * 40
  SOURCE = "/var/tmp/rs-source.synthetic"
  TARGET = "/etc/opt/readersourcing/rs-server"

  def source_containers
    DeploymentLayoutConfiguration::SOURCE_SERVICES.each_with_index.map do |service, index|
      id = (index + 1).to_s * 64
      image = service == "rs_server_webapp" ? IMAGE : "sha256:#{index.to_s * 64}"
      bindings = DeploymentLayoutConfiguration::RUNTIME_BINDINGS.fetch(service, {}).map do |name, target|
        {"Type" => "bind", "Source" => "#{SOURCE}/runtime/#{name}", "Destination" => target, "Mode" => "ro", "RW" => false, "Propagation" => "rprivate"}
      end
      if %w[database rs_server_webapp].include?(service)
        bindings << {"Type" => "volume", "Source" => "/var/lib/docker/volumes/retained/_data", "Destination" => "/data",
          "Name" => service == "database" ? "#{PROJECT}_database" : "#{PROJECT}_publications", "RW" => true}
      end
      {"Id" => id, "Name" => "/#{PROJECT}-#{service}-1", "Image" => image, "RestartCount" => 0,
        "Config" => {"Hostname" => id[0, 12], "Image" => "original-tag", "Env" => ["PRIVATE=synthetic", "OTHER=value"],
          "User" => "1000:1000", "Cmd" => ["original-command"], "Labels" => {
            "com.docker.compose.project" => PROJECT, "com.docker.compose.service" => service,
            "com.docker.compose.project.config_files" => "#{SOURCE}/compose.yml", "com.docker.compose.project.working_dir" => SOURCE,
            "com.docker.compose.config-hash" => "e" * 64, "com.docker.compose.depends_on" => service == "rs_server_webapp" ? "database:service_healthy:false,rs_server_setup:service_completed_successfully:false" : "",
            "org.opencontainers.image.revision" => REVISION}},
        "HostConfig" => {"ConsoleSize" => [0, 0], "RestartPolicy" => {"Name" => "no"}, "ReadonlyRootfs" => true,
          "CapDrop" => ["ALL"], "SecurityOpt" => ["no-new-privileges:true"], "Memory" => 128 * 1024 * 1024,
          "Mounts" => bindings.select { |mount| mount["Type"] == "bind" }.map { |mount| {"Type" => "bind", "Source" => mount["Source"], "Target" => mount["Destination"], "ReadOnly" => true} }},
        "Mounts" => bindings, "NetworkSettings" => {"Networks" => {"#{PROJECT}_default" => {"IPAddress" => "172.18.0.2"}}},
        "State" => {"Running" => service != "rs_server_setup", "StartedAt" => "2026-10-15T10:00:00Z", "ExitCode" => 0,
          "Paused" => false, "Restarting" => false, "Dead" => false}}
    end
  end

  def replacements(source)
    current = JSON.parse(JSON.generate(source))
    current.each do |entry|
      service = entry["Config"]["Labels"]["com.docker.compose.service"]
      next unless DeploymentLayoutInventory::REPLACED.include?(service)
      original_id = entry["Id"]
      entry["Id"] = Digest::SHA256.hexdigest(original_id)
      entry["Config"]["Hostname"] = entry["Id"][0, 12]
      entry["Config"]["Image"] = entry["Image"]
      entry["State"]["Running"] = false
      entry["State"]["StartedAt"] = "0001-01-01T00:00:00Z"
      labels = entry["Config"]["Labels"]
      labels["com.docker.compose.config-hash"] = "f" * 64
      labels["com.docker.compose.project.config_files"] = "#{TARGET}/compose.json"
      labels["com.docker.compose.project.working_dir"] = TARGET
      labels["com.docker.compose.replace"] = original_id
      labels["com.docker.compose.depends_on"] = "database:service_healthy:false" if service == "rs_server_webapp"
      (entry["Mounts"] + entry["HostConfig"]["Mounts"]).each do |mount|
        mount["Source"] = mount["Source"].sub(SOURCE, TARGET) if mount["Type"] == "bind"
      end
    end
    current
  end
end
