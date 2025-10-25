# OAuth callback controller for user authentication.
# Handles Google OAuth2 authentication flow.
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # Handles successful Google OAuth2 authentication
  # Creates or updates user and Google account, then signs in the user
  # GET /users/auth/google_oauth2/callback
  def google_oauth2
    auth_data = request.env["omniauth.auth"]

    # Step 1: Find or create user (idempotent)
    @user = User.from_omniauth(auth_data)

    # TODO: make this a saga pattern to handle multi-step process with rollbacks on failure
    if @user.persisted?
      # Step 2: Update or create Google account (idempotent)
      google_account = @user.update_google_account(auth_data)

      # Determine if this was a new connection or refresh
      message = google_account.created_at == google_account.updated_at ?
                "Google Calendar access granted successfully!" :
                "Google Calendar access refreshed successfully!"

      # Step 3: Populate starter content if user is new and has no content
      UserOnboardingService.populate_starter_content(@user)

      flash[:notice] = message
      sign_in_and_redirect @user, event: :authentication
    else
      # User creation failed
      Rails.logger.error "User creation failed for email: #{auth_data.info.email}"
      flash[:alert] = "There was a problem creating your account. Please try again."
      redirect_to new_user_registration_url
    end
  end

  # Handles OAuth authentication failures
  # Logs error and redirects to root with error message
  # GET /users/auth/google_oauth2/callback (when authentication fails)
  def failure
    error_message = params[:message]
    Rails.logger.error "OAuth failure: #{error_message} - #{params[:error_description]}"
    flash[:alert] = "Authentication failed: #{error_message}"
    redirect_to root_path
  end
end
