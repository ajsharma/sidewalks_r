class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      # Update or create Google account with OAuth data
      @user.update_google_account(request.env["omniauth.auth"])

      flash[:notice] = "Google Calendar access granted successfully!"
      sign_in_and_redirect @user, event: :authentication
    else
      flash[:alert] = "There was a problem connecting your Google account."
      redirect_to new_user_registration_url
    end
  end

  def failure
    flash[:alert] = "Authentication failed: #{params[:message]}"
    redirect_to root_path
  end
end