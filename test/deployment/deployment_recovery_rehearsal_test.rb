require_relative "private_trial_recovery_rehearsal_test"

class DeploymentRecoveryRehearsalTest < PrivateTrialRecoveryRehearsalTest
  OPERATIONS = File.expand_path("../../deploy/private/deployment_operations.sh", __dir__)
  ADAPTER = File.expand_path("../../deploy/private/deployment_recovery.sh", __dir__)

  def recovery_fake
    FAKE.sub("/definition/recovery_configuration.rb", "/definition/deployment_recovery_configuration.rb")
  end

  def recovery_adapter
    <<~SH
      . '#{OPERATIONS}'
      . '#{ADAPTER}'
      rs_recovery_configuration_script=deployment_recovery_configuration.rb
    SH
  end

  def test_new_layout_uses_the_checked_definition_and_protected_report_directory
    run_recovery("success") do |_output, errors, status, commands, root|
      assert status.success?, errors
      assert commands.any? { |args| args.include?("/definition/deployment_recovery_configuration.rb") }
      source_export = commands.find { |args| args.first == "compose" && args.include?("config") }
      assert source_export.any? { |arg| arg.end_with?("/source/compose.json") }
      report = File.join(root, "state", "recovery-latest.json")
      assert_equal "recovery_rehearsal_passed", JSON.parse(File.read(report))["status"]
      assert_equal 0o600, File.stat(report).mode & 0o777
      refute File.exist?(File.join(root, "operations", "recovery-report.json"))
    end
  end
end
