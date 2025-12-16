require "rails_helper"

RSpec.describe ApplicationJob, type: :job do
  it "inherits from ActiveJob::Base" do
    expect(described_class < ActiveJob::Base).to be_truthy
  end

  it "has retry and discard configurations available" do
    # Test that the class has the expected structure for retry_on and discard_on
    # These are commented out in the actual class but the structure exists
    expect(described_class).to respond_to(:retry_on)
    expect(described_class).to respond_to(:discard_on)
  end
end
