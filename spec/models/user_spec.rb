require "rails_helper"
require "ostruct"

RSpec.describe User, type: :model do
  before do
    @user = User.new(
      email: "test@example.com",
      password: "password",
      name: "Test User"
    )
  end

  it "should be valid" do
    expect(@user).to be_valid
  end

  it "should require email" do
    @user.email = ""
    expect(@user).not_to be_valid
    expect(@user.errors[:email]).to include("can't be blank")
  end

  it "should require name" do
    @user.name = ""
    expect(@user).not_to be_valid
    expect(@user.errors[:name]).to include("can't be blank")
  end

  it "should require unique email" do
    @user.save!
    duplicate_user = @user.dup
    expect(duplicate_user).not_to be_valid
    expect(duplicate_user.errors[:email]).to include("has already been taken")
  end

  it "should generate slug from name" do
    @user.save!
    expect(@user.slug).to eq("test-user")
  end

  it "should generate unique slug when name conflicts" do
    @user.save!
    user2 = User.create!(
      email: "test2@example.com",
      password: "password",
      name: "Test User"
    )
    expect(user2.slug).to eq("test-user-1")
  end

  it "should require unique slug" do
    @user.save!
    user2 = User.new(
      email: "test2@example.com",
      password: "password",
      name: "Different Name",
      slug: "test-user"
    )
    expect(user2).not_to be_valid
    expect(user2.errors[:slug]).to include("has already been taken")
  end

  it "should validate timezone" do
    @user.timezone = "Invalid/Timezone"
    expect(@user).not_to be_valid
    expect(@user.errors[:timezone]).to include("is not included in the list")
  end

  it "should allow valid timezone" do
    @user.timezone = "Eastern Time (US & Canada)"
    @user.valid?
    expect(@user.errors[:timezone]).to be_empty
  end

  it "should set default timezone on create" do
    @user.timezone = nil
    @user.save!
    expect(@user.timezone).to eq("Pacific Time (US & Canada)")
  end

  it "should use to_param as slug" do
    @user.save!
    expect(@user.to_param).to eq(@user.slug)
  end

  it "archived? should return false when not archived" do
    expect(@user.archived?).to be_falsey
  end

  it "archived? should return true when archived" do
    @user.archived_at = Time.current
    expect(@user.archived?).to be_truthy
  end

  it "archive! should set archived_at" do
    @user.save!
    expect(@user.archived_at).to be_nil
    @user.archive!
    expect(@user.archived_at).not_to be_nil
  end

  it "should have many activities" do
    @user.save!
    activity = @user.activities.create!(name: "Test Activity")
    expect(@user.activities).to include(activity)
  end

  it "should have many playlists" do
    @user.save!
    playlist = @user.playlists.create!(name: "Test Playlist")
    expect(@user.playlists).to include(playlist)
  end

  it "should have many google_accounts" do
    @user.save!
    google_account = @user.google_accounts.create!(
      email: "test@gmail.com",
      google_id: "123456"
    )
    expect(@user.google_accounts).to include(google_account)
  end

  it "active scope should exclude archived users" do
    active_user = users(:one)
    archived_user = User.create!(
      email: "archived@example.com",
      password: "password",
      name: "Archived User",
      archived_at: Time.current
    )

    active_users = User.active
    expect(active_users).to include(active_user)
    expect(active_users).not_to include(archived_user)
  end

  it "from_omniauth should find existing user by email" do
    @user.save!
    auth = OpenStruct.new(
      info: OpenStruct.new(email: @user.email, name: "Updated Name"),
      uid: "123456"
    )

    found_user = User.from_omniauth(auth)
    expect(found_user).to eq(@user)
  end

  it "from_omniauth should create new user when email not found" do
    auth = OpenStruct.new(
      info: OpenStruct.new(email: "new@example.com", name: "New User"),
      uid: "123456"
    )

    expect { User.from_omniauth(auth) }.to change { User.count }.by(1)
  end
end
