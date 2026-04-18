class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :api_user

  def user
    api_user || session&.user
  end
end
