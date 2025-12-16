require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  it "module exists" do
    expect(defined?(described_class)).to be_truthy
    expect(described_class).to be_a(Module)
  end
end
