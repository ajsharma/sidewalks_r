require "rails_helper"

RSpec.describe "AiActivities::Retries", type: :request do
  before do
    @user = users(:one)
    sign_in @user
  end

  describe "POST /ai_activities/:ai_activity_id/retry" do
    it "queues background job for failed suggestion" do
      suggestion = ai_activity_suggestions(:failed_suggestion)

      expect {
        post ai_activity_retry_path(suggestion), as: :json
      }.to have_enqueued_job(AiSuggestionGeneratorJob)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("processing")
      expect(json["request_id"]).not_to be_nil

      suggestion.reload
      expect(suggestion.status).to eq("processing")
      expect(suggestion.error_message).to be_nil
    end

    it "returns error for accepted suggestion" do
      suggestion = ai_activity_suggestions(:accepted_suggestion)
      sign_out @user
      sign_in users(:two)

      post ai_activity_retry_path(suggestion), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]).to match(/Cannot retry accepted suggestions/)
    end

    it "creates new suggestion for completed suggestion" do
      suggestion = ai_activity_suggestions(:text_completed)

      expect {
        expect {
          post ai_activity_retry_path(suggestion), as: :json
        }.to have_enqueued_job(AiSuggestionGeneratorJob)
      }.to change(AiActivitySuggestion, :count).by(1)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("processing")
      expect(json["request_id"]).not_to be_nil
      expect(json["new_suggestion_id"]).not_to be_nil

      # Original suggestion should be unchanged
      suggestion.reload
      expect(suggestion.status).to eq("completed")

      # New suggestion should be created
      new_suggestion = AiActivitySuggestion.find(json["new_suggestion_id"])
      expect(new_suggestion.status).to eq("pending")
      expect(new_suggestion.input_text).to eq(suggestion.input_text)
      expect(new_suggestion.input_type).to eq(suggestion.input_type)
    end

    it "renders HTML for failed suggestion" do
      suggestion = ai_activity_suggestions(:failed_suggestion)

      expect {
        post ai_activity_retry_path(suggestion)
      }.to have_enqueued_job(AiSuggestionGeneratorJob)

      expect(response).to redirect_to(ai_activities_path)
      expect(flash[:notice]).to eq("Generating new AI suggestion...")
    end

    it "renders HTML for completed suggestion" do
      suggestion = ai_activity_suggestions(:text_completed)

      expect {
        expect {
          post ai_activity_retry_path(suggestion)
        }.to have_enqueued_job(AiSuggestionGeneratorJob)
      }.to change(AiActivitySuggestion, :count).by(1)

      expect(response).to redirect_to(ai_activities_path)
      expect(flash[:notice]).to eq("Generating new AI suggestion...")
    end

    it "returns 404 for other user's suggestion" do
      other_user_suggestion = ai_activity_suggestions(:accepted_suggestion)
      post ai_activity_retry_path(other_user_suggestion), as: :json
      expect(response).to have_http_status(:not_found)
    end

    it "requires authentication" do
      sign_out @user
      suggestion = ai_activity_suggestions(:failed_suggestion)
      post ai_activity_retry_path(suggestion), as: :json
      expect(response).to have_http_status(:unauthorized)
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
