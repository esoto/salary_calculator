class ChangeOauthAuthorizationCodesRedirectUriLimit < ActiveRecord::Migration[8.1]
  def up
    change_column :oauth_authorization_codes, :redirect_uri, :string, limit: 2048, null: false
  end

  def down
    change_column :oauth_authorization_codes, :redirect_uri, :string, null: false
  end
end
