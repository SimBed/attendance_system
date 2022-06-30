class ApplicationController < ActionController::Base
  include ApplicationHelper
  include SessionsHelper

  # https://www.ruby-forum.com/t/the-change-you-want-was-rejected-maybe-you-changed-something-you-didnt-have-access-to/183945/2
  # Added to manage a hopefully resolved CSRF error
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_token_issues

  def handle_token_issues
    flash[:warning] = 'Session expired. If this continues, please try clearing your cache.'
    redirect_to(login_path)
  end
end
