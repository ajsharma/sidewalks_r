require "rails_helper"

RSpec.describe ActivitiesHelper, type: :helper do
  it "schedule_type_options returns correct options" do
    options = schedule_type_options

    expect(options.size).to eq(4)
    expect(options).to include([ "Flexible - Can be done anytime", "flexible" ])
    expect(options).to include([ "Strict - Specific date and time", "strict" ])
    expect(options).to include([ "Deadline - Must be done before a certain date", "deadline" ])
    expect(options).to include([ "Recurring - Repeats on a schedule", "recurring_strict" ])
  end

  it "max_frequency_options returns correct options" do
    options = max_frequency_options

    expect(options.size).to eq(7)
    expect(options).to include([ "Daily", 1 ])
    expect(options).to include([ "Monthly", 30 ])
    expect(options).to include([ "Every 2 months", 60 ])
    expect(options).to include([ "Every 3 months", 90 ])
    expect(options).to include([ "Every 6 months", 180 ])
    expect(options).to include([ "Yearly", 365 ])
    expect(options).to include([ "Never repeat", nil ])
  end

  it "schedule_type_options has correct structure" do
    options = schedule_type_options
    options.each do |option|
      expect(option.size).to eq(2)
      expect(option[0]).to be_an_instance_of(String)
      expect(option[1]).to be_an_instance_of(String)
    end
  end

  it "max_frequency_options has correct structure" do
    options = max_frequency_options
    options.each do |option|
      expect(option.size).to eq(2)
      expect(option[0]).to be_an_instance_of(String)
      expect(option[1].is_a?(Integer) || option[1].nil?).to be_truthy
    end
  end
end
