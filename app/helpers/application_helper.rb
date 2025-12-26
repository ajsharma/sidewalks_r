# Application-wide view helper methods.
# Contains utility methods used across multiple views.
module ApplicationHelper
  # Sanitize URL to only allow http/https protocols
  # Returns the URL if safe, nil otherwise
  def safe_url(url)
    return nil if url.blank?

    uri = URI.parse(url)
    uri.scheme.in?(%w[http https]) ? url : nil
  rescue URI::InvalidURIError
    nil
  end

  # Get the timezone for displaying times
  # Uses current user's timezone if signed in, otherwise defaults to Pacific Time
  # (since most events in the system are from San Francisco area)
  def display_timezone
    user_signed_in? ? current_user.timezone : "Pacific Time (US & Canada)"
  end
end
