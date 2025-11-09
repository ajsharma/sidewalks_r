require "application_system_test_case"

class AiSuggestionsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in @user
    ENV["AI_FEATURE_ENABLED"] = "true"
    ENV["ANTHROPIC_API_KEY"] = "test-key"
  end

  teardown do
    ENV["AI_FEATURE_ENABLED"] = nil
  end

  test "visiting the AI suggestions index" do
    visit ai_activities_path

    assert_selector "h1", text: "AI Activity Suggestions"
    assert_selector "textarea[name='input']"
    assert_button "Generate Suggestion"
  end

  test "index shows existing suggestions" do
    suggestion = ai_activity_suggestions(:text_completed)

    visit ai_activities_path

    assert_text suggestion.suggested_activity_name
    assert_text suggestion.confidence_label
  end

  test "submitting text generates suggestion (async)" do
    stub_successful_claude_api

    visit ai_activities_path

    fill_in "input", with: "Go hiking this weekend"
    click_button "Generate Suggestion"

    # Form should show processing state
    assert_button "Processing...", disabled: true

    # After submission, status message should appear
    assert_text "AI is processing your request", wait: 2

    # Input should be cleared
    assert_field "input", with: ""
  end

  test "viewing a suggestion detail page" do
    suggestion = ai_activity_suggestions(:text_completed)

    visit ai_activity_path(suggestion)

    assert_text suggestion.suggested_activity_name
    assert_text "Review & Edit"
    assert_field "name", with: suggestion.suggested_data["name"]
    assert_button "Accept & Create Activity"
  end

  test "accepting a suggestion creates an activity" do
    suggestion = ai_activity_suggestions(:text_completed)

    visit ai_activity_path(suggestion)

    fill_in "name", with: "My Custom Activity Name"
    click_button "Accept & Create Activity"

    # Should redirect to the new activity
    assert_current_path %r{/activities/\w+}
    assert_text "My Custom Activity Name"
  end

  test "dismissing a suggestion from index" do
    suggestion = ai_activity_suggestions(:text_completed)

    visit ai_activities_path

    within "#suggestion_#{suggestion.id}" do
      accept_confirm do
        click_link "Dismiss"
      end
    end

    # Suggestion should be marked as not accepted
    suggestion.reload
    assert_not suggestion.accepted
  end

  test "navigation shows AI Suggestions link" do
    visit root_path

    assert_link "AI Suggestions"
    click_link "AI Suggestions"

    assert_current_path ai_activities_path
  end

  test "shows empty state when no suggestions" do
    @user.ai_suggestions.destroy_all

    visit ai_activities_path

    assert_text "No suggestions yet"
    assert_text "Get started by describing an activity above"
  end

  test "displays failed suggestion with error message" do
    failed = ai_activity_suggestions(:failed_suggestion)

    visit ai_activities_path

    within "#suggestion_#{failed.id}" do
      assert_text "Failed"
      assert_text failed.error_message
    end
  end

  test "editing suggestion fields before accepting" do
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
    assert_equal "Edited Activity Name", activity.name
    assert_equal "strict", activity.schedule_type
    assert_includes activity.suggested_months, 6
    assert_includes activity.suggested_months, 7
    assert_includes activity.suggested_days_of_week, 0
    assert_includes activity.suggested_days_of_week, 6
  end

  test "shows confidence score with appropriate styling" do
    high_confidence = ai_activity_suggestions(:url_completed)  # 92% confidence

    visit ai_activities_path

    within "#suggestion_#{high_confidence.id}" do
      # High confidence should show as green
      assert_selector "span", text: "High confidence"
    end
  end

  test "displays category tags" do
    suggestion = ai_activity_suggestions(:text_completed)

    visit ai_activities_path

    within "#suggestion_#{suggestion.id}" do
      suggestion.suggested_data["category_tags"].each do |tag|
        assert_text tag
      end
    end
  end

  test "shows AI reasoning in collapsible section" do
    suggestion = ai_activity_suggestions(:text_completed)

    visit ai_activities_path

    within "#suggestion_#{suggestion.id}" do
      # Initially collapsed
      assert_selector "details summary", text: "Why AI suggested this scheduling"

      # Click to expand
      find("details summary").click

      assert_text suggestion.suggested_data["reasoning"]
    end
  end

  test "redirects when AI feature is disabled" do
    ENV["AI_FEATURE_ENABLED"] = "false"

    visit ai_activities_path

    assert_current_path root_path
    assert_text "AI suggestions are not currently available"
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
