require "test_helper"

class Users::OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @auth_data = {
      "provider" => "google_oauth2",
      "uid" => "123456789",
      "info" => {
        "email" => "test@example.com",
        "name" => "Test User"
      },
      "credentials" => {
        "token" => "access_token",
        "refresh_token" => "refresh_token",
        "expires_at" => 1.hour.from_now.to_i
      }
    }

    Rails.application.env_config["devise.mapping"] = Devise.mappings[:user]
    Rails.application.env_config["omniauth.auth"] = OmniAuth::AuthHash.new(@auth_data)
    OmniAuth.config.test_mode = true
  end

  test "controller exists and has correct parent class" do
    assert_includes Users::OmniauthCallbacksController.ancestors, Devise::OmniauthCallbacksController
  end

  test "controller has google_oauth2 method" do
    assert Users::OmniauthCallbacksController.instance_methods.include?(:google_oauth2)
  end

  test "controller has failure method" do
    assert Users::OmniauthCallbacksController.instance_methods.include?(:failure)
  end
end
