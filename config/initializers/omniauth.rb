Rails.application.config.middleware.use OmniAuth::Builder do
  # Only configure Google OAuth if credentials are present
  if Rails.application.credentials.google.present?
    provider :google_oauth2,
             Rails.application.credentials.google[:client_id],
             Rails.application.credentials.google[:client_secret],
             {
               scope: "email,profile,https://www.googleapis.com/auth/calendar",  # Include calendar access
               access_type: "offline",       # Required for refresh tokens
               prompt: "consent"             # Force consent to get refresh token
             }
  end
end

OmniAuth.config.allowed_request_methods = [ :post, :get ]
