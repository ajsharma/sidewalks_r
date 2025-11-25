require "rails_helper"

RSpec.describe GoogleAccount, type: :model do
  before do
    @user = users(:one)
    @google_account = GoogleAccount.new(
      user: @user,
      email: "test@gmail.com",
      google_id: "123456789",
      access_token: "test_access_token",
      refresh_token: "test_refresh_token",
      expires_at: Time.current + 1.hour
    )
  end

  it "should be valid" do
    expect(@google_account).to be_valid
  end

  it "should require user" do
    @google_account.user = nil
    expect(@google_account).not_to be_valid
    expect(@google_account.errors[:user]).to include("must exist")
  end

  it "should require email" do
    @google_account.email = ""
    expect(@google_account).not_to be_valid
    expect(@google_account.errors[:email]).to include("can't be blank")
  end

  it "should validate email format" do
    @google_account.email = "invalid_email"
    expect(@google_account).not_to be_valid
    expect(@google_account.errors[:email]).to include("is invalid")
  end

  it "should require google_id" do
    @google_account.google_id = ""
    expect(@google_account).not_to be_valid
    expect(@google_account.errors[:google_id]).to include("can't be blank")
  end

  it "should require unique google_id per user" do
    @google_account.save!
    duplicate = GoogleAccount.new(
      user: @user,
      email: "different@gmail.com",
      google_id: @google_account.google_id
    )
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:google_id]).to include("has already been taken")
  end

  it "should allow same google_id for different users" do
    @google_account.save!
    other_user = User.create!(
      email: "other@example.com",
      password: "password",
      name: "Other User"
    )
    different_account = GoogleAccount.new(
      user: other_user,
      email: "different@gmail.com",
      google_id: @google_account.google_id
    )
    expect(different_account).to be_valid
  end

  it "archived? should return false when not archived" do
    expect(@google_account.archived?).to be_falsey
  end

  it "archived? should return true when archived" do
    @google_account.archived_at = Time.current
    expect(@google_account.archived?).to be_truthy
  end

  it "archive! should set archived_at" do
    @google_account.save!
    expect(@google_account.archived_at).to be_nil
    @google_account.archive!
    expect(@google_account.archived_at).not_to be_nil
  end

  it "token_expired? should return false when token not expired" do
    @google_account.expires_at = Time.current + 1.hour
    expect(@google_account.token_expired?).to be_falsey
  end

  it "token_expired? should return true when token expired" do
    @google_account.expires_at = Time.current - 1.hour
    expect(@google_account.token_expired?).to be_truthy
  end

  it "token_expired? should return false when expires_at is nil" do
    @google_account.expires_at = nil
    expect(@google_account.token_expired?).to be_falsey
  end

  it "calendars should parse JSON calendar_list" do
    calendar_data = [ { "id" => "primary", "summary" => "Primary Calendar" } ]
    @google_account.calendar_list = calendar_data.to_json
    expect(@google_account.calendars).to eq(calendar_data)
  end

  it "calendars should return empty array for invalid JSON" do
    @google_account.calendar_list = "invalid json"
    expect(@google_account.calendars).to eq([])
  end

  it "calendars should return empty array when calendar_list is nil" do
    @google_account.calendar_list = nil
    expect(@google_account.calendars).to eq([])
  end

  it "calendars= should store calendars as JSON" do
    calendar_data = [ { "id" => "primary", "summary" => "Primary Calendar" } ]
    @google_account.calendars = calendar_data
    expect(@google_account.calendar_list).to eq(calendar_data.to_json)
  end

  it "needs_refresh? should return true when token expired" do
    @google_account.expires_at = Time.current - 1.hour
    expect(@google_account.needs_refresh?).to be_truthy
  end

  it "needs_refresh? should return true when access_token is blank" do
    @google_account.access_token = ""
    expect(@google_account.needs_refresh?).to be_truthy
  end

  it "needs_refresh? should return false when token valid and present" do
    @google_account.expires_at = Time.current + 1.hour
    @google_account.access_token = "valid_token"
    expect(@google_account.needs_refresh?).to be_falsey
  end

  it "active scope should exclude archived accounts" do
    active_account = google_accounts(:one)
    archived_account = GoogleAccount.create!(
      user: @user,
      email: "archived@gmail.com",
      google_id: "archived123",
      archived_at: Time.current
    )

    active_accounts = GoogleAccount.active
    expect(active_accounts).to include(active_account)
    expect(active_accounts).not_to include(archived_account)
  end
end
