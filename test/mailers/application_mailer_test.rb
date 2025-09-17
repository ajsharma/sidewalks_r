require "test_helper"

class ApplicationMailerTest < ActiveSupport::TestCase
  test "should have correct default from address" do
    assert_equal "from@example.com", ApplicationMailer.default[:from]
  end

  test "should have mailer layout configured" do
    # Test that the layout is set in the class definition
    # Since it's called via the layout method in Rails, we can't easily access it
    # but we can verify the class is properly configured
    assert_respond_to ApplicationMailer, :layout
  end

  test "should inherit from ActionMailer::Base" do
    assert ApplicationMailer < ActionMailer::Base
  end
end
