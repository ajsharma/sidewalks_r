# Configuration class for AI-related settings using Anyway Config.
# Supports multiple sources: YAML config, Rails credentials, and ENV variables.
#
# Priority (highest to lowest):
#   1. ENV variables (ANTHROPIC_API_KEY, AI_FEATURE_ENABLED)
#   2. Rails credentials (Rails.application.credentials.ai.anthropic_api_key)
#   3. YAML config (config/ai.yml)
#
# Usage:
#   AiConfig.instance.anthropic_api_key
#   AiConfig.instance.feature_enabled?
class AiConfig < Anyway::Config
  config_name :ai

  # AI service configuration
  attr_config :anthropic_api_key,
              :feature_enabled,
              :rate_limit_per_hour,
              :rate_limit_per_day,
              :default_model

  # Defaults
  attr_config rate_limit_per_hour: 20,
              rate_limit_per_day: 100,
              default_model: "claude-3-5-sonnet-20241022",
              feature_enabled: false

  # Helper methods
  def feature_enabled?
    # Convert string "true"/"false" to boolean
    case feature_enabled
    when true, "true", "1"
      true
    else
      false
    end
  end

  def api_key_configured?
    anthropic_api_key.present? && anthropic_api_key != "ABC_123"
  end

  # Singleton instance for app-wide access
  def self.instance
    @instance ||= new
  end
end
