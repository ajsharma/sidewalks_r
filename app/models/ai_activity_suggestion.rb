# Model for tracking AI-generated activity suggestions.
# Stores user input, AI responses, lifecycle status, and relationship to created activities.
# == Schema Information
#
# Table name: ai_activity_suggestions
#
#  id                 :bigint           not null, primary key
#  accepted           :boolean          default(FALSE)
#  accepted_at        :datetime
#  api_request        :jsonb
#  api_response       :jsonb
#  confidence_score   :decimal(5, 2)
#  error_message      :text
#  extracted_metadata :jsonb
#  input_text         :text
#  input_type         :string           default("text"), not null
#  model_used         :string
#  processing_time_ms :integer
#  source_url         :text
#  status             :string           default("pending")
#  suggested_data     :jsonb
#  user_edits         :jsonb
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  final_activity_id  :bigint
#  user_id            :bigint           not null
#
# Indexes
#
#  index_ai_activity_suggestions_on_accepted                (accepted)
#  index_ai_activity_suggestions_on_created_at              (created_at)
#  index_ai_activity_suggestions_on_final_activity_id       (final_activity_id)
#  index_ai_activity_suggestions_on_input_type              (input_type)
#  index_ai_activity_suggestions_on_status                  (status)
#  index_ai_activity_suggestions_on_user_id                 (user_id)
#  index_ai_activity_suggestions_on_user_id_and_created_at  (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (final_activity_id => activities.id)
#  fk_rails_...  (user_id => users.id)
#
class AiActivitySuggestion < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :final_activity, class_name: "Activity", optional: true

  # Enums
  enum :input_type, { text: "text", url: "url" }, validate: true
  enum :status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }, validate: true

  # Validations
  validates :input_type, presence: true
  validates :input_text, presence: true, if: -> { text? }
  validates :source_url, presence: true, if: -> { url? }
  validates :source_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true }
  validates :confidence_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }

  # Callbacks
  before_validation :normalize_input

  # Instance methods
  def accept!(activity)
    transaction do
      update!(
        accepted: true,
        accepted_at: Time.current,
        final_activity: activity,
        status: "completed"
      )
    end
  end

  def reject!
    update!(accepted: false, status: "completed")
  end

  def mark_completed!(data = {})
    update!(
      status: "completed",
      suggested_data: data,
      confidence_score: data[:confidence_score] || data["confidence_score"]
    )
  end

  def mark_failed!(error)
    update!(
      status: "failed",
      error_message: error.message
    )
  end

  def retry!
    update!(
      status: "processing",
      error_message: nil
    )
  end

  def processing_cost
    # Estimate cost based on Claude 3.5 Sonnet pricing
    # Input: $3/MTok, Output: $15/MTok
    return 0 unless api_response.present?

    input_tokens = api_response.dig("usage", "input_tokens") || 0
    output_tokens = api_response.dig("usage", "output_tokens") || 0

    (input_tokens / 1_000_000.0 * 3.0) + (output_tokens / 1_000_000.0 * 15.0)
  end

  def suggested_activity_name
    suggested_data["name"] || "Untitled Activity"
  end

  def confidence_label
    return "Unknown" unless confidence_score

    case confidence_score
    when 0..30
      "Low confidence"
    when 31..65
      "Moderate confidence"
    when 66..85
      "Good confidence"
    when 86..100
      "High confidence"
    else
      "Unknown"
    end
  end

  private

  def normalize_input
    self.input_text = input_text&.strip
    self.source_url = source_url&.strip
  end
end
