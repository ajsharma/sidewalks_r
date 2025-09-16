class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    auth_data = request.env["omniauth.auth"]

    # Step 1: Find or create user (idempotent)
    @user = User.from_omniauth(auth_data)

    if @user.persisted?
      begin
        # Step 2: Update or create Google account (idempotent)
        google_account = @user.update_google_account(auth_data)

        # Determine if this was a new connection or refresh
        message = google_account.created_at == google_account.updated_at ?
                  "Google Calendar access granted successfully!" :
                  "Google Calendar access refreshed successfully!"

        flash[:notice] = message
        sign_in_and_redirect @user, event: :authentication

      rescue StandardError => e
        Rails.logger.error "Google OAuth callback error: #{e.message}"
        flash[:alert] = "There was a problem connecting your Google account. Please try again."
        redirect_to new_user_session_path
      end
    else
      # User creation failed
      Rails.logger.error "User creation failed for email: #{auth_data.info.email}"
      flash[:alert] = "There was a problem creating your account. Please try again."
      redirect_to new_user_registration_url
    end
  end

  def failure
    Rails.logger.error "OAuth failure: #{params[:message]} - #{params[:error_description]}"
    flash[:alert] = "Authentication failed: #{params[:message]}"
    redirect_to root_path
  end
end