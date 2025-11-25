require "rails_helper"

RSpec.describe "Health", type: :request do
  it "should get basic health check" do
    get "/health"
    expect(response).to have_http_status(:success)

    json_response = JSON.parse(response.body)
    expect(json_response["overall_status"]).to eq("healthy")
    expect(json_response["checks"]["database"]["status"]).to eq("healthy")
    expect(json_response["checks"]["rails_app"]["status"]).to eq("healthy")
  end

  it "should get detailed health check" do
    get "/health/detailed"
    expect(response).to have_http_status(:success)

    json_response = JSON.parse(response.body)
    expect(json_response["overall_status"]).to eq("healthy")
    expect(json_response["checks"].key?("database")).to be_truthy
    expect(json_response["checks"].key?("rails_app")).to be_truthy
    expect(json_response["checks"].key?("memory")).to be_truthy
  end

  it "should get readiness probe" do
    get "/health/ready"
    expect(response).to have_http_status(:success)

    json_response = JSON.parse(response.body)
    expect(json_response["overall_status"]).to eq("ready")
  end

  it "should get liveness probe" do
    get "/health/live"
    expect(response).to have_http_status(:success)

    json_response = JSON.parse(response.body)
    expect(json_response["status"]).to eq("alive")
    expect(json_response.key?("uptime")).to be_truthy
    expect(json_response.key?("version")).to be_truthy
  end

  it "health check should include performance metrics" do
    get "/health"
    expect(response).to have_http_status(:success)

    json_response = JSON.parse(response.body)
    expect(json_response.key?("response_time_ms")).to be_truthy
    expect(json_response["response_time_ms"].is_a?(Numeric)).to be_truthy
    expect(json_response.key?("timestamp")).to be_truthy
  end

  it "detailed health check should include system metrics" do
    get "/health/detailed"
    expect(response).to have_http_status(:success)

    json_response = JSON.parse(response.body)
    expect(json_response.key?("uptime_seconds")).to be_truthy
    expect(json_response["checks"]["rails_app"].key?("ruby_version")).to be_truthy
    expect(json_response["checks"]["memory"].key?("ruby_memory_mb")).to be_truthy
  end
end
