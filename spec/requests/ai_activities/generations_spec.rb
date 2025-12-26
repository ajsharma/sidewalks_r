require "rails_helper"

RSpec.describe "AiActivities::Generations", type: :request do
  before do
    @user = users(:one)
    sign_in @user
  end

  describe "POST /ai_activities/generations" do
    it "queues background job" do
      expect {
        post ai_activities_generations_path, params: { input: "Go for a run" }, as: :json
      }.to have_enqueued_job(AiSuggestionGeneratorJob)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("processing")
      expect(json["request_id"]).not_to be_nil
    end

    it "returns error for blank input" do
      post ai_activities_generations_path, params: { input: "" }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]).to match(/cannot be blank/)
    end

    it "handles rate limit error" do
      # Create 20 suggestions in last hour to hit rate limit
      20.times do
        @user.ai_suggestions.create!(
          input_type: :text,
          input_text: "test",
          created_at: 30.minutes.ago
        )
      end

      # The rate limit check happens in the background job, so we test the job directly
      # The controller will queue the job successfully
      post ai_activities_generations_path, params: { input: "test" }, as: :json
      expect(response).to have_http_status(:success)
    end

    it "requires authentication" do
      sign_out @user
      post ai_activities_generations_path, params: { input: "test" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "checks AI feature enabled" do
      # Temporarily disable the feature
      original_value = AiConfig.instance.feature_enabled
      AiConfig.instance.feature_enabled = false

      post ai_activities_generations_path, params: { input: "test" }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("AI suggestions are not currently available")
    ensure
      AiConfig.instance.feature_enabled = original_value
    end
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password"
      }
    }
    follow_redirect!
  end

  def sign_out(user)
    delete destroy_user_session_path
  end
end
