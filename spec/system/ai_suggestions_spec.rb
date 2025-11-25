require "rails_helper"

RSpec.describe "AiSuggestions", type: :system do
  before do
    @user = users(:one)
    sign_in @user
    # AI config is loaded from config/ai.yml test environment
  end

  it "visiting the AI suggestions index" do
    visit ai_activities_path

    expect(page).to have_selector "h1", text: "AI Activity Suggestions"
    expect(page).to have_selector "textarea[name='input']"
    expect(page).to have_button "Generate Suggestion"
  end

  it "index shows existing suggestions" do
    suggestion = ai_activity_suggestions(:text_completed)

    visit ai_activities_path

    expect(page).to have_content suggestion.suggested_activity_name
    expect(page).to have_content suggestion.confidence_label
  end

  it "submitting text generates suggestion (async)" do
    stub_successful_claude_api

    visit ai_activities_path

    fill_in "input", with: "Go hiking this weekend"
    click_button "Generate Suggestion"

    # Form should show processing state
    expect(page).to have_button "Processing...", disabled: true

    # After submission, status message should appear
    expect(page).to have_content "AI is processing your request", wait: 2

    # Input should be cleared
    expect(page).to have_field "input", with: ""
  end

  it "viewing a suggestion detail page" do
    suggestion = ai_activity_suggestions(:text_completed)

    visit ai_activity_path(suggestion)

    expect(page).to have_content suggestion.suggested_activity_name
    expect(page).to have_content "Review & Edit"
    expect(page).to have_field "name", with: suggestion.suggested_data["name"]
    expect(page).to have_button "Accept & Create Activity"
  end

  it "accepting a suggestion creates an activity" do
    suggestion = ai_activity_suggestions(:text_completed)

    visit ai_activity_path(suggestion)

    fill_in "name", with: "My Custom Activity Name"
    click_button "Accept & Create Activity"

    # Should redirect to the new activity
    expect(page).to have_current_path %r{/activities/\w+}
    expect(page).to have_content "My Custom Activity Name"
  end

  it "dismissing a suggestion from index" do
    suggestion = ai_activity_suggestions(:text_completed)

    visit ai_activities_path

    within "#suggestion_#{suggestion.id}" do
      accept_confirm do
        click_link "Dismiss"
      end
    end

    # Suggestion should be marked as not accepted
    suggestion.reload
    expect(suggestion.accepted).to be false
  end

  it "navigation shows AI Suggestions link" do
    visit root_path

    expect(page).to have_link "AI Suggestions"
    click_link "AI Suggestions"

    expect(page).to have_current_path ai_activities_path
  end

  it "shows empty state when no suggestions" do
    @user.ai_suggestions.destroy_all

    visit ai_activities_path

    expect(page).to have_content "No suggestions yet"
    expect(page).to have_content "Get started by describing an activity above"
  end

  it "displays failed suggestion with error message" do
    failed = ai_activity_suggestions(:failed_suggestion)

    visit ai_activities_path

    within "#suggestion_#{failed.id}" do
      expect(page).to have_content "Failed"
      expect(page).to have_content failed.error_message
    end
  end

  it "editing suggestion fields before accepting" do
    suggestion = ai_activity_suggestions(:text_completed)

    visit ai_activity_path(suggestion)

    # Edit the name
    fill_in "name", with: "Edited Activity Name"

    # Change schedule type
    select "Strict - Specific date/time", from: "schedule_type"

    # Select some months
    check "month_6"  # June
    check "month_7"  # July

    # Select some days
    check "day_0"  # Sunday
    check "day_6"  # Saturday

    click_button "Accept & Create Activity"

    # Activity should be created with edited values
    activity = Activity.last
    expect(activity.name).to eq "Edited Activity Name"
    expect(activity.schedule_type).to eq "strict"
    expect(activity.suggested_months).to include 6
    expect(activity.suggested_months).to include 7
    expect(activity.suggested_days_of_week).to include 0
    expect(activity.suggested_days_of_week).to include 6
  end

  it "shows confidence score with appropriate styling" do
    high_confidence = ai_activity_suggestions(:url_completed)  # 92% confidence

    visit ai_activities_path

    within "#suggestion_#{high_confidence.id}" do
      # High confidence should show as green
      expect(page).to have_selector "span", text: "High confidence"
    end
  end

  it "displays category tags" do
    suggestion = ai_activity_suggestions(:text_completed)

    visit ai_activities_path

    within "#suggestion_#{suggestion.id}" do
      suggestion.suggested_data["category_tags"].each do |tag|
        expect(page).to have_content tag
      end
    end
  end

  it "shows AI reasoning in collapsible section" do
    suggestion = ai_activity_suggestions(:text_completed)

    visit ai_activities_path

    within "#suggestion_#{suggestion.id}" do
      # Initially collapsed
      expect(page).to have_selector "details summary", text: "Why AI suggested this scheduling"

      # Click to expand
      find("details summary").click

      expect(page).to have_content suggestion.suggested_data["reasoning"]
    end
  end

  it "redirects when AI feature is disabled" do
    ENV["AI_FEATURE_ENABLED"] = "false"

    visit ai_activities_path

    expect(page).to have_current_path root_path
    expect(page).to have_content "AI suggestions are not currently available"
  end

  private

  def stub_successful_claude_api
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(
        status: 200,
        body: {
          content: [ {
            text: {
              name: "Hiking Trip",
              description: "Outdoor hiking activity",
              schedule_type: "flexible",
              suggested_months: [ 6, 7, 8 ],
              suggested_days_of_week: [ 0, 6 ],
              suggested_time_of_day: "morning",
              category_tags: [ "outdoor", "exercise" ],
              confidence_score: 85,
              reasoning: "Hiking is best in summer months on weekends"
            }.to_json
          } ],
          model: "claude-3-5-sonnet-20241022",
          usage: { input_tokens: 100, output_tokens: 150 }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end
