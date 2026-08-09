require "test_helper"

class PaperRatingReferenceTest < ActiveSupport::TestCase

  test "identifies the reader and publication without an automatic expiration" do
    reference = PaperRatingReference.issue(
      user: users(:one),
      publication: publications(:two)
    )

    travel 1.year do
      assert_equal users(:one), PaperRatingReference.resolve(
        reference,
        publication: publications(:two)
      )
    end
  end

  test "is independent from active authentication tokens" do
    reference = PaperRatingReference.issue(
      user: users(:one),
      publication: publications(:two)
    )
    users(:one).authentication_tokens.delete_all

    assert_equal users(:one), PaperRatingReference.resolve(
      reference,
      publication: publications(:two)
    )
  end

  test "cannot be transferred to another publication or altered" do
    reference = PaperRatingReference.issue(
      user: users(:one),
      publication: publications(:two)
    )

    assert_nil PaperRatingReference.resolve(reference, publication: publications(:one))
    assert_nil PaperRatingReference.resolve("#{reference}altered", publication: publications(:two))
  end

  test "recognizes a legacy JWT reference during its original lifetime" do
    auth_token = JsonWebToken.encode(
      {
        user_id: users(:one).id,
        ip_address: "127.0.0.1"
      },
      1.hour.from_now
    )
    reference = legacy_reference_for(auth_token)

    assert_equal users(:one), PaperRatingReference.resolve(
      reference,
      publication: publications(:two)
    )
  end

  private

  def legacy_reference_for(auth_token)
    key_length = ActiveSupport::MessageEncryptor.key_len
    salt = SecureRandom.hex(key_length)
    key = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(salt, key_length)
    encrypted_token = ActiveSupport::MessageEncryptor.new(key).encrypt_and_sign(auth_token)
    "#{salt}!!!!!#{encrypted_token}"
  end

end
