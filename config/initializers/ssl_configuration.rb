# SSL Configuration for API clients
# Fixes "certificate verify failed" errors on macOS

# Set SSL_CERT_FILE to point to Homebrew's CA certificates
# This is needed for ruby-openai and other HTTP clients
cert_file = OpenSSL::X509::DEFAULT_CERT_FILE
if File.exist?(cert_file)
  ENV["SSL_CERT_FILE"] ||= cert_file
  ENV["SSL_CERT_DIR"] ||= File.dirname(cert_file)
end

# Configure Faraday (used by ruby-openai) to use these certs
if defined?(Faraday)
  Faraday.default_connection_options = {
    ssl: {
      verify: true,
      ca_file: ENV["SSL_CERT_FILE"],
      verify_mode: OpenSSL::SSL::VERIFY_PEER
    }
  }
end
