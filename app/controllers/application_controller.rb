class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_paper_trail_whodunnit

  helper SalaryEntriesHelper
  helper_method :current_user, :authenticated?

  private

  def current_user
    Current.user
  end

  def authenticated?
    Current.user.present?
  end

  def user_for_paper_trail
    current_user&.id
  end
end
