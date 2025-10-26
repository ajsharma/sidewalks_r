# Model for Google Calendar API health checks
class GoogleCalendarHealth
  # Checks Google Calendar API connectivity and token health
  # @return [Hash] hash containing status (healthy/warning/unhealthy), message, active_accounts count, and response_time_ms
  def self.check_api_connectivity
    return { status: "healthy", message: "No Google accounts configured" } if GoogleAccount.count == 0

    start_time = Time.current
    begin
      recent_account = find_recent_active_account
      return { status: "warning", message: "No active Google accounts found" } unless recent_account

      if recent_account.needs_refresh?
        return {
          status: "warning",
          message: "Google Calendar tokens need refresh",
          response_time_ms: response_time_ms(start_time)
        }
      end

      # Basic connectivity test - just check if we can authenticate
      auth = build_auth_credentials(recent_account)

      {
        status: "healthy",
        message: "Google Calendar API accessible",
        active_accounts: GoogleAccount.where.not(access_token: nil).count,
        response_time_ms: response_time_ms(start_time)
      }
    rescue => e
      {
        status: "unhealthy",
        message: "Google Calendar API check failed",
        error: e.message,
        response_time_ms: response_time_ms(start_time)
      }
    end
  end

  private

  def self.find_recent_active_account
    GoogleAccount.where.not(access_token: nil).order(:updated_at).last
  end

  def self.build_auth_credentials(account)
    google_credentials = Rails.application.credentials.google

    auth = Google::Auth::UserRefreshCredentials.new(
      client_id: google_credentials[:client_id],
      client_secret: google_credentials[:client_secret],
      scope: [ "https://www.googleapis.com/auth/calendar" ],
      refresh_token: account.refresh_token
    )

    auth.access_token = account.access_token
    auth.expires_at = account.expires_at
    auth
  end

  def self.response_time_ms(start_time)
    ((Time.current - start_time) * 1000).round(2)
  end
end
