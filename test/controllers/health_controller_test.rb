require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  test "should get basic health check" do
    get "/health"
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "healthy", json_response["overall_status"]
    assert json_response["checks"]["database"]["status"] == "healthy"
    assert json_response["checks"]["rails_app"]["status"] == "healthy"
  end

  test "should get detailed health check" do
    get "/health/detailed"
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "healthy", json_response["overall_status"]
    assert json_response["checks"].key?("database")
    assert json_response["checks"].key?("rails_app")
    assert json_response["checks"].key?("memory")
  end

  test "should get readiness probe" do
    get "/health/ready"
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "ready", json_response["overall_status"]
  end

  test "should get liveness probe" do
    get "/health/live"
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "alive", json_response["status"]
    assert json_response.key?("uptime")
    assert json_response.key?("version")
  end

  test "health check should include performance metrics" do
    get "/health"
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.key?("response_time_ms")
    assert json_response["response_time_ms"].is_a?(Numeric)
    assert json_response.key?("timestamp")
  end

  test "detailed health check should include system metrics" do
    get "/health/detailed"
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.key?("uptime_seconds")
    assert json_response["checks"]["rails_app"].key?("ruby_version")
    assert json_response["checks"]["memory"].key?("ruby_memory_mb")
  end
end
