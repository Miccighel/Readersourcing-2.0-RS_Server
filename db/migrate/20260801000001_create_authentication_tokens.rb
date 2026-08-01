class CreateAuthenticationTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :authentication_tokens do |t|
      t.references :user, null: false, foreign_key: {on_delete: :cascade}
      t.string :jti, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :authentication_tokens, :jti, unique: true
    add_index :authentication_tokens, :expires_at
  end
end
