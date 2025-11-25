require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  it "module exists" do
    expect(defined?(ApplicationHelper)).to be_truthy
    expect(ApplicationHelper.is_a?(Module)).to be_truthy
  end
end
