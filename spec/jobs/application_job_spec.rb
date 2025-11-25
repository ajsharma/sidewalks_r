require "rails_helper"

RSpec.describe ApplicationJob, type: :job do
  it "should inherit from ActiveJob::Base" do
    expect(ApplicationJob < ActiveJob::Base).to be_truthy
  end

  it "should have retry and discard configurations available" do
    # Test that the class has the expected structure for retry_on and discard_on
    # These are commented out in the actual class but the structure exists
    expect(ApplicationJob).to respond_to(:retry_on)
    expect(ApplicationJob).to respond_to(:discard_on)
  end
end
