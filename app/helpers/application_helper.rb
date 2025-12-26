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
end
