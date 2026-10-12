require "test_helper"
require "resolv"

class ResolvRuntimeTest < ActiveSupport::TestCase

  test "the application uses the locked corrected resolver" do
    assert_equal Gem.loaded_specs.fetch("resolv").version.to_s, Resolv::VERSION
    assert_operator Gem::Version.new(Resolv::VERSION), :>=, Gem::Version.new("0.7.2")
  end

  test "DNS names exceeding the label limit are rejected before encoding" do
    assert_raises(Resolv::ResolvError) { Resolv::DNS::Name.create("#{'a' * 64}.example.test") }
  end

  test "unknown DNS record types do not accumulate permanent classes" do
    resource = Resolv::DNS::Resource
    constants_before = resource.constants.sort

    32.times do |index|
      response = [123, 0x8180, 0, 1, 0, 0].pack("n6")
      response << "\0" << [60_000 + index, 1, 0, 4].pack("nnNn") << "test"
      assert_equal 1, Resolv::DNS::Message.decode(response).answer.length
    end

    assert_equal constants_before, resource.constants.sort
  end

  test "unknown DNS service parameters do not accumulate permanent classes" do
    parameters = Resolv::DNS::SvcParam
    constants_before = parameters::Generic.constants.sort
    classes_before = parameters::ClassHash.size

    32.times { |index| parameters::ClassHash[60_000 + index] }

    assert_equal constants_before, parameters::Generic.constants.sort
    assert_equal classes_before, parameters::ClassHash.size
  end

end
