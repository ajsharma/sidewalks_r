require "rails_helper"

RSpec.describe "AiActivities::Rejections", type: :request do
  before do
    @user = users(:one)
    sign_in @user
  end

  describe "POST /ai_activities/:ai_activity_id/rejection" do
    it "marks suggestion as rejected" do
      suggestion = ai_activity_suggestions(:text_completed)

      post ai_activity_rejection_path(suggestion), as: :json

      expect(response).to have_http_status(:success)
      suggestion.reload
      expect(suggestion.accepted).to be_falsey
      expect(suggestion.status).to eq("completed")
    end

    it "requires authentication" do
      sign_out @user
      suggestion = ai_activity_suggestions(:text_completed)
      post ai_activity_rejection_path(suggestion), as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 404 for other user's suggestion" do
      other_user_suggestion = ai_activity_suggestions(:accepted_suggestion)
      post ai_activity_rejection_path(other_user_suggestion), as: :json
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
