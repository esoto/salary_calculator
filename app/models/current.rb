class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :user_override

  def user
    user_override || session&.user
  end
end
