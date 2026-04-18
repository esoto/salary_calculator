class CreateApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token_digest, null: false
      t.string :token_hash, null: false
      t.string :scopes, null: false, default: ""
      t.boolean :active, null: false, default: true
      t.datetime :expires_at
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :api_tokens, :token_hash, unique: true
    add_index :api_tokens, :token_digest, unique: true
    add_index :api_tokens, [ :user_id, :active ]
  end
end
