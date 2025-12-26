require "rails_helper"

RSpec.describe "AiActivities", type: :request do
  before do
    @user = users(:one)
    sign_in @user
  end

  describe "GET /ai_activities" do
    it "requires authentication" do
      sign_out @user
      get ai_activities_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "returns user's suggestions as JSON" do
      get ai_activities_path, as: :json
      expect(response).to have_http_status(:success)
    end

    it "renders HTML view" do
      get ai_activities_path
      expect(response).to have_http_status(:success)
      assert_select "h1", text: "AI Activity Suggestions"
      assert_select "textarea[name='input']"
    end

    it "checks AI feature enabled" do
      # Temporarily disable the feature
      original_value = AiConfig.instance.feature_enabled
      AiConfig.instance.feature_enabled = false

      get ai_activities_path
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("AI suggestions are not currently available")
    ensure
      AiConfig.instance.feature_enabled = original_value
    end
  end

  describe "GET /ai_activities/:id" do
    it "displays suggestion as JSON" do
      suggestion = ai_activity_suggestions(:text_completed)
      get ai_activity_path(suggestion), as: :json
      expect(response).to have_http_status(:success)
    end

    it "renders HTML view" do
      suggestion = ai_activity_suggestions(:text_completed)
      get ai_activity_path(suggestion)
      expect(response).to have_http_status(:success)
      assert_select "h1", text: suggestion.suggested_activity_name
      assert_select "input[name='name']"
      assert_select "input[type='submit'][value='Accept & Create Activity']"
    end

    it "renders HTML view with nil api_response" do
      suggestion = ai_activity_suggestions(:completed_with_nil_api_response)
      get ai_activity_path(suggestion)
      expect(response).to have_http_status(:success)
      assert_select "h1", text: suggestion.suggested_activity_name
      assert_select "input[name='name']"
    end

    it "returns 404 for other user's suggestion" do
      other_user_suggestion = ai_activity_suggestions(:accepted_suggestion)
      get ai_activity_path(other_user_suggestion), as: :json
      expect(response).to have_http_status(:not_found)
    end

    it "requires authentication" do
      sign_out @user
      suggestion = ai_activity_suggestions(:text_completed)
      get ai_activity_path(suggestion)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "DELETE /ai_activities/:id" do
    it "deletes suggestion" do
      suggestion = ai_activity_suggestions(:text_completed)

      expect {
        delete ai_activity_path(suggestion), as: :json
      }.to change(AiActivitySuggestion, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "requires authentication" do
      sign_out @user
      suggestion = ai_activity_suggestions(:text_completed)
      delete ai_activity_path(suggestion), as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 404 for other user's suggestion" do
      other_user_suggestion = ai_activity_suggestions(:accepted_suggestion)
      delete ai_activity_path(other_user_suggestion), as: :json
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
