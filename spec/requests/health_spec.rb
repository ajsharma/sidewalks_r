require "rails_helper"

RSpec.describe "Health", type: :request do
  it "gets basic health check" do
    get "/health"
    expect(response).to have_http_status(:success)

    json_response = JSON.parse(response.body)
    expect(json_response["overall_status"]).to eq("healthy")
    expect(json_response["checks"]["database"]["status"]).to eq("healthy")
    expect(json_response["checks"]["rails_app"]["status"]).to eq("healthy")
  end

  it "gets detailed health check" do
    get "/health/detailed"
    expect(response).to have_http_status(:success)

    json_response = JSON.parse(response.body)
    expect(json_response["overall_status"]).to eq("healthy")
    expect(json_response["checks"]).to be_key("database")
    expect(json_response["checks"]).to be_key("rails_app")
    expect(json_response["checks"]).to be_key("memory")
  end

  it "gets readiness probe" do
    get "/health/ready"
    expect(response).to have_http_status(:success)

    json_response = JSON.parse(response.body)
    expect(json_response["overall_status"]).to eq("ready")
  end

  it "gets liveness probe" do
    get "/health/live"
    expect(response).to have_http_status(:success)

    json_response = JSON.parse(response.body)
    expect(json_response["status"]).to eq("alive")
    expect(json_response).to be_key("uptime")
    expect(json_response).to be_key("version")
  end

  it "health check should include performance metrics" do
    get "/health"
    expect(response).to have_http_status(:success)

    json_response = JSON.parse(response.body)
    expect(json_response).to be_key("response_time_ms")
    expect(json_response["response_time_ms"]).to be_a(Numeric)
    expect(json_response).to be_key("timestamp")
  end

  it "detailed health check should include system metrics" do
    get "/health/detailed"
    expect(response).to have_http_status(:success)

    json_response = JSON.parse(response.body)
    expect(json_response).to be_key("uptime_seconds")
    expect(json_response["checks"]["rails_app"]).to be_key("ruby_version")
    expect(json_response["checks"]["memory"]).to be_key("ruby_memory_mb")
  end
end
