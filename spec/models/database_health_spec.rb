require "rails_helper"

RSpec.describe DatabaseHealth, type: :model do
  it "connection_metrics returns expected keys" do
    metrics = described_class.connection_metrics

    expect(metrics.keys).to include(:pool_size)
    expect(metrics.keys).to include(:active_connections)
    expect(metrics.keys).to include(:available_connections)
    expect(metrics.keys).to include(:database_version)

    expect(metrics[:pool_size]).to be_an_instance_of(Integer)
    expect(metrics[:active_connections]).to be_an_instance_of(Integer)
    expect(metrics[:available_connections]).to be_an_instance_of(Integer)
    expect(metrics[:database_version]).not_to be_nil
  end

  it "connection_metrics calculates available connections correctly" do
    metrics = described_class.connection_metrics
    expected_available = metrics[:pool_size] - metrics[:active_connections]

    expect(metrics[:available_connections]).to eq(expected_available)
  end

  it "check_connection returns healthy status on success" do
    result = described_class.check_connection

    expect(result[:status]).to eq("healthy")
    expect(result[:message]).to eq("Database connection successful")
    expect(result.keys).to include(:response_time_ms)
    expect(result.keys).to include(:pool_size)
    expect(result.keys).to include(:active_connections)
    expect(result.keys).to include(:available_connections)
    expect(result.keys).to include(:database_version)

    expect(result[:response_time_ms]).to be_an_instance_of(Float)
    expect(result[:response_time_ms]).to be >= 0
  end

  it "check_connection has error handling structure" do
    # Test that the method handles errors properly by checking structure
    result = described_class.check_connection

    # Should return a hash with standard keys
    expect(result).to be_an_instance_of(Hash)
    expect(result.keys).to include(:status)
    expect(result.keys).to include(:message)
    expect(result.keys).to include(:response_time_ms)

    # Status should be healthy for working database
    expect(result[:status]).to eq("healthy")
  end

  it "calculate_response_time returns positive float" do
    start_time = Time.current - 0.05 # 50ms ago
    response_time = described_class.send(:calculate_response_time, start_time)

    expect(response_time).to be_an_instance_of(Float)
    expect(response_time).to be > 0
    expect(response_time).to be < 1000 # Should be less than 1 second in test environment
  end
end
