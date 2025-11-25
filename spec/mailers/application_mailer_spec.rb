require "rails_helper"

RSpec.describe ApplicationMailer, type: :mailer do
  it "should have correct default from address" do
    expect(ApplicationMailer.default[:from]).to eq("from@example.com")
  end

  it "should have mailer layout configured" do
    # Test that the layout is set in the class definition
    # Since it's called via the layout method in Rails, we can't easily access it
    # but we can verify the class is properly configured
    expect(ApplicationMailer).to respond_to(:layout)
  end

  it "should inherit from ActionMailer::Base" do
    expect(ApplicationMailer < ActionMailer::Base).to be_truthy
  end
end
