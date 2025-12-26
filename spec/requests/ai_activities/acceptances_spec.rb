require "rails_helper"

RSpec.describe "AiActivities::Acceptances", type: :request do
  before do
    @user = users(:one)
    sign_in @user
  end

  describe "POST /ai_activities/:ai_activity_id/acceptance" do
    it "creates activity from suggestion" do
      suggestion = ai_activity_suggestions(:text_completed)

      expect {
        post ai_activity_acceptance_path(suggestion), as: :json
      }.to change(Activity, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["activity"]).not_to be_nil
      expect(json["message"]).to eq("Activity created successfully")

      suggestion.reload
      expect(suggestion.accepted).to be_truthy
    end

    it "applies user edits" do
      suggestion = ai_activity_suggestions(:text_completed)

      post ai_activity_acceptance_path(suggestion), params: {
        name: "Custom Name",
        description: "Custom Description"
      }, as: :json

      expect(response).to have_http_status(:created)
      activity = Activity.last
      expect(activity.name).to eq("Custom Name")
      expect(activity.description).to eq("Custom Description")
    end

    it "requires authentication" do
      sign_out @user
      suggestion = ai_activity_suggestions(:text_completed)
      post ai_activity_acceptance_path(suggestion), as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 404 for other user's suggestion" do
      other_user_suggestion = ai_activity_suggestions(:accepted_suggestion)
      post ai_activity_acceptance_path(other_user_suggestion), as: :json
      expect(response).to have_http_status(:not_found)
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
