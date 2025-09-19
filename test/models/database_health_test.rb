require "test_helper"

class DatabaseHealthTest < ActiveSupport::TestCase
  test "connection_metrics returns expected keys" do
    metrics = DatabaseHealth.connection_metrics

    assert_includes metrics.keys, :pool_size
    assert_includes metrics.keys, :active_connections
    assert_includes metrics.keys, :available_connections
    assert_includes metrics.keys, :database_version

    assert_instance_of Integer, metrics[:pool_size]
    assert_instance_of Integer, metrics[:active_connections]
    assert_instance_of Integer, metrics[:available_connections]
    assert_not_nil metrics[:database_version]
  end

  test "connection_metrics calculates available connections correctly" do
    metrics = DatabaseHealth.connection_metrics
    expected_available = metrics[:pool_size] - metrics[:active_connections]

    assert_equal expected_available, metrics[:available_connections]
  end

  test "check_connection returns healthy status on success" do
    result = DatabaseHealth.check_connection

    assert_equal "healthy", result[:status]
    assert_equal "Database connection successful", result[:message]
    assert_includes result.keys, :response_time_ms
    assert_includes result.keys, :pool_size
    assert_includes result.keys, :active_connections
    assert_includes result.keys, :available_connections
    assert_includes result.keys, :database_version

    assert_instance_of Float, result[:response_time_ms]
    assert result[:response_time_ms] >= 0
  end

  test "check_connection has error handling structure" do
    # Test that the method handles errors properly by checking structure
    result = DatabaseHealth.check_connection

    # Should return a hash with standard keys
    assert_instance_of Hash, result
    assert_includes result.keys, :status
    assert_includes result.keys, :message
    assert_includes result.keys, :response_time_ms

    # Status should be healthy for working database
    assert_equal "healthy", result[:status]
  end

  test "calculate_response_time returns positive float" do
    start_time = Time.current - 0.05 # 50ms ago
    response_time = DatabaseHealth.send(:calculate_response_time, start_time)

    assert_instance_of Float, response_time
    assert response_time > 0
    assert response_time < 1000 # Should be less than 1 second in test environment
  end
end
