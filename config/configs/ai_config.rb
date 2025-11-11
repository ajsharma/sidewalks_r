# Configuration class for AI-related settings using Anyway Config.
# Supports multiple sources: YAML config, Rails credentials, and ENV variables.
#
# Priority (highest to lowest):
#   1. ENV variables (AI_PROVIDER, ANTHROPIC_API_KEY, OPENAI_API_KEY, AI_FEATURE_ENABLED)
#   2. Rails credentials (Rails.application.credentials.ai.*)
#   3. YAML config (config/ai.yml)
#
# Usage:
#   AiConfig.instance.provider               # "anthropic" or "openai"
#   AiConfig.instance.anthropic_api_key
#   AiConfig.instance.openai_api_key
#   AiConfig.instance.feature_enabled?
class AiConfig < Anyway::Config
  config_name :ai

  # AI provider selection
  attr_config :provider  # "anthropic" or "openai"

  # API keys for different providers
  attr_config :anthropic_api_key,
              :openai_api_key

  # General AI configuration
  attr_config :feature_enabled,
              :rate_limit_per_hour,
              :rate_limit_per_day

  # Provider-specific models
  attr_config :anthropic_model,
              :openai_model

  # Defaults
  attr_config provider: "openai",  # Default to OpenAI/ChatGPT
              rate_limit_per_hour: 20,
              rate_limit_per_day: 100,
              anthropic_model: "claude-3-5-sonnet-20241022",
              openai_model: "gpt-4o",
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
    case provider
    when "anthropic"
      anthropic_api_key.present? && anthropic_api_key != "ABC_123"
    when "openai"
      openai_api_key.present? && openai_api_key != "ABC_123"
    else
      false
    end
  end

  def current_api_key
    case provider
    when "anthropic"
      anthropic_api_key
    when "openai"
      openai_api_key
    else
      raise "Unknown AI provider: #{provider}"
    end
  end

  def current_model
    case provider
    when "anthropic"
      anthropic_model
    when "openai"
      openai_model
    else
      raise "Unknown AI provider: #{provider}"
    end
  end

  def using_anthropic?
    provider == "anthropic"
  end

  def using_openai?
    provider == "openai"
  end

  # Singleton instance for app-wide access
  def self.instance
    @instance ||= new
  end
end
