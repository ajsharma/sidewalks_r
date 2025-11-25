require "rails_helper"

RSpec.describe "Users::OmniauthCallbacks", type: :request do
  before do
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

  it "controller exists and has correct parent class" do
    expect(Users::OmniauthCallbacksController.ancestors).to include(Devise::OmniauthCallbacksController)
  end

  it "controller has google_oauth2 method" do
    expect(Users::OmniauthCallbacksController.instance_methods).to include(:google_oauth2)
  end

  it "controller has failure method" do
    expect(Users::OmniauthCallbacksController.instance_methods).to include(:failure)
  end
end
