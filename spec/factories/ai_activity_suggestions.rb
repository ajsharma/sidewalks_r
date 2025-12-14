FactoryBot.define do
  factory :ai_activity_suggestion do
    association :user
    input_type { "text" }
    input_text { "Go hiking on a weekend" }
    source_url { nil }
    model_used { nil }
    processing_time_ms { nil }
    confidence_score { nil }
    extracted_metadata { {} }
    api_request { {} }
    api_response { {} }
    suggested_data { {} }
    user_edits { {} }
    final_activity { nil }
    accepted { false }
    accepted_at { nil }
    status { "pending" }
    error_message { nil }

    trait :completed do
      status { "completed" }
      model_used { "claude-3-5-sonnet-20241022" }
      processing_time_ms { 1500 }
      confidence_score { 85.5 }
      api_request { { "input" => input_text } }
      api_response { { "usage" => { "input_tokens" => 150, "output_tokens" => 200 } } }
      suggested_data do
        {
          "name" => "Farmers Market Visit",
          "description" => "Visit local farmers market",
          "schedule_type" => "flexible",
          "suggested_months" => [ 5, 6, 7, 8, 9 ],
          "suggested_days_of_week" => [ 0, 6 ],
          "suggested_time_of_day" => "morning",
          "category_tags" => [ "outdoor", "food", "social" ],
          "confidence_score" => 85.5,
          "reasoning" => "Farmers markets are seasonal and typically open on weekend mornings"
        }
      end
    end

    trait :failed do
      status { "failed" }
      error_message { "Failed to fetch URL: Could not resolve host" }
    end

    trait :from_url do
      input_type { "url" }
      input_text { nil }
      source_url { "https://example.com/event" }
    end

    trait :accepted do
      accepted { true }
      accepted_at { 1.day.ago }
    end
  end
end
