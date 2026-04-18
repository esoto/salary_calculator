class CreateOauthAuthorizationCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_authorization_codes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :code_digest, null: false
      t.string :redirect_uri, null: false
      t.string :scopes, null: false, default: ""
      t.datetime :expires_at, null: false
      t.datetime :used_at

      t.timestamps
    end

    add_index :oauth_authorization_codes, :code_digest, unique: true
    add_index :oauth_authorization_codes, :expires_at
  end
end
