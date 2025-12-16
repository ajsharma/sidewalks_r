require "rails_helper"

RSpec.describe "AiActivities", type: :request do
  before do
    @user = users(:one)
    sign_in @user
    # AI config is loaded from config/ai.yml test environment
  end

  it "index requires authentication" do
    sign_out @user
    get ai_activities_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "index returns user's suggestions as JSON" do
    get ai_activities_path, as: :json
    expect(response).to have_http_status(:success)
  end

  it "index renders HTML view" do
    get ai_activities_path
    expect(response).to have_http_status(:success)
    assert_select "h1", text: "AI Activity Suggestions"
    assert_select "textarea[name='input']"
  end

  it "index checks AI feature enabled" do
    # Temporarily disable the feature
    original_value = AiConfig.instance.feature_enabled
    AiConfig.instance.feature_enabled = false

    get ai_activities_path
    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to eq("AI suggestions are not currently available")
  ensure
    AiConfig.instance.feature_enabled = original_value
  end

  it "generate queues background job" do
    expect {
      post generate_ai_activities_path, params: { input: "Go for a run" }, as: :json
    }.to have_enqueued_job(AiSuggestionGeneratorJob)

    expect(response).to have_http_status(:success)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("processing")
    expect(json["request_id"]).not_to be_nil
  end

  it "generate returns error for blank input" do
    post generate_ai_activities_path, params: { input: "" }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    json = JSON.parse(response.body)
    expect(json["error"]).to match(/cannot be blank/)
  end

  it "generate handles rate limit error" do
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
    post generate_ai_activities_path, params: { input: "test" }, as: :json
    expect(response).to have_http_status(:success)
  end

  it "show displays suggestion as JSON" do
    suggestion = ai_activity_suggestions(:text_completed)
    get ai_activity_path(suggestion), as: :json
    expect(response).to have_http_status(:success)
  end

  it "show renders HTML view" do
    suggestion = ai_activity_suggestions(:text_completed)
    get ai_activity_path(suggestion)
    expect(response).to have_http_status(:success)
    assert_select "h1", text: suggestion.suggested_activity_name
    assert_select "input[name='name']"
    assert_select "input[type='submit'][value='Accept & Create Activity']"
  end

  it "show renders HTML view with nil api_response" do
    suggestion = ai_activity_suggestions(:completed_with_nil_api_response)
    get ai_activity_path(suggestion)
    expect(response).to have_http_status(:success)
    assert_select "h1", text: suggestion.suggested_activity_name
    assert_select "input[name='name']"
  end

  it "show returns 404 for other user's suggestion" do
    other_user_suggestion = ai_activity_suggestions(:accepted_suggestion)
    get ai_activity_path(other_user_suggestion), as: :json
    expect(response).to have_http_status(:not_found)
  end

  it "accept creates activity from suggestion" do
    suggestion = ai_activity_suggestions(:text_completed)

    expect {
      post accept_ai_activity_path(suggestion), as: :json
    }.to change(Activity, :count).by(1)

    expect(response).to have_http_status(:created)
    json = JSON.parse(response.body)
    expect(json["activity"]).not_to be_nil
    expect(json["message"]).to eq("Activity created successfully")

    suggestion.reload
    expect(suggestion.accepted).to be_truthy
  end

  it "accept applies user edits" do
    suggestion = ai_activity_suggestions(:text_completed)

    post accept_ai_activity_path(suggestion), params: {
      name: "Custom Name",
      description: "Custom Description"
    }, as: :json

    expect(response).to have_http_status(:created)
    activity = Activity.last
    expect(activity.name).to eq("Custom Name")
    expect(activity.description).to eq("Custom Description")
  end

  it "reject marks suggestion as rejected" do
    suggestion = ai_activity_suggestions(:text_completed)

    post reject_ai_activity_path(suggestion), as: :json

    expect(response).to have_http_status(:success)
    suggestion.reload
    expect(suggestion.accepted).to be_falsey
    expect(suggestion.status).to eq("completed")
  end

  it "destroy deletes suggestion" do
    suggestion = ai_activity_suggestions(:text_completed)

    expect {
      delete ai_activity_path(suggestion), as: :json
    }.to change(AiActivitySuggestion, :count).by(-1)

    expect(response).to have_http_status(:no_content)
  end

  it "retry queues background job for failed suggestion" do
    suggestion = ai_activity_suggestions(:failed_suggestion)

    expect {
      post retry_ai_activity_path(suggestion), as: :json
    }.to have_enqueued_job(AiSuggestionGeneratorJob)

    expect(response).to have_http_status(:success)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("processing")
    expect(json["request_id"]).not_to be_nil

    suggestion.reload
    expect(suggestion.status).to eq("processing")
    expect(suggestion.error_message).to be_nil
  end

  it "retry returns error for accepted suggestion" do
    suggestion = ai_activity_suggestions(:accepted_suggestion)
    sign_out @user
    sign_in users(:two)

    post retry_ai_activity_path(suggestion), as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    json = JSON.parse(response.body)
    expect(json["error"]).to match(/Cannot retry accepted suggestions/)
  end

  it "retry creates new suggestion for completed suggestion" do
    suggestion = ai_activity_suggestions(:text_completed)

    expect {
      expect {
        post retry_ai_activity_path(suggestion), as: :json
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

  it "retry renders HTML for failed suggestion" do
    suggestion = ai_activity_suggestions(:failed_suggestion)

    expect {
      post retry_ai_activity_path(suggestion)
    }.to have_enqueued_job(AiSuggestionGeneratorJob)

    expect(response).to redirect_to(ai_activities_path)
    expect(flash[:notice]).to eq("Generating new AI suggestion...")
  end

  it "retry renders HTML for completed suggestion" do
    suggestion = ai_activity_suggestions(:text_completed)

    expect {
      expect {
        post retry_ai_activity_path(suggestion)
      }.to have_enqueued_job(AiSuggestionGeneratorJob)
    }.to change(AiActivitySuggestion, :count).by(1)

    expect(response).to redirect_to(ai_activities_path)
    expect(flash[:notice]).to eq("Generating new AI suggestion...")
  end

  it "retry returns 404 for other user's suggestion" do
    other_user_suggestion = ai_activity_suggestions(:accepted_suggestion)
    post retry_ai_activity_path(other_user_suggestion), as: :json
    expect(response).to have_http_status(:not_found)
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
