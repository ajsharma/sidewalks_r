require "test_helper"
require "ostruct"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = User.new(
      email: "test@example.com",
      password: "password",
      name: "Test User"
    )
  end

  test "should be valid" do
    assert @user.valid?
  end

  test "should require email" do
    @user.email = ""
    assert_not @user.valid?
    assert_includes @user.errors[:email], "can't be blank"
  end

  test "should require name" do
    @user.name = ""
    assert_not @user.valid?
    assert_includes @user.errors[:name], "can't be blank"
  end

  test "should require unique email" do
    @user.save!
    duplicate_user = @user.dup
    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:email], "has already been taken"
  end

  test "should generate slug from name" do
    @user.save!
    assert_equal "test-user", @user.slug
  end

  test "should generate unique slug when name conflicts" do
    @user.save!
    user2 = User.create!(
      email: "test2@example.com",
      password: "password",
      name: "Test User"
    )
    assert_equal "test-user-1", user2.slug
  end

  test "should require unique slug" do
    @user.save!
    user2 = User.new(
      email: "test2@example.com",
      password: "password",
      name: "Different Name",
      slug: "test-user"
    )
    assert_not user2.valid?
    assert_includes user2.errors[:slug], "has already been taken"
  end

  test "should validate timezone" do
    @user.timezone = "Invalid/Timezone"
    assert_not @user.valid?
    assert_includes @user.errors[:timezone], "is not included in the list"
  end

  test "should allow valid timezone" do
    @user.timezone = "Eastern Time (US & Canada)"
    @user.valid?
    assert_empty @user.errors[:timezone]
  end

  test "should set default timezone on create" do
    @user.timezone = nil
    @user.save!
    assert_equal "Pacific Time (US & Canada)", @user.timezone
  end

  test "should use to_param as slug" do
    @user.save!
    assert_equal @user.slug, @user.to_param
  end

  test "archived? should return false when not archived" do
    assert_not @user.archived?
  end

  test "archived? should return true when archived" do
    @user.archived_at = Time.current
    assert @user.archived?
  end

  test "archive! should set archived_at" do
    @user.save!
    assert_nil @user.archived_at
    @user.archive!
    assert_not_nil @user.archived_at
  end

  test "should have many activities" do
    @user.save!
    activity = @user.activities.create!(name: "Test Activity")
    assert_includes @user.activities, activity
  end

  test "should have many playlists" do
    @user.save!
    playlist = @user.playlists.create!(name: "Test Playlist")
    assert_includes @user.playlists, playlist
  end

  test "should have many google_accounts" do
    @user.save!
    google_account = @user.google_accounts.create!(
      email: "test@gmail.com",
      google_id: "123456"
    )
    assert_includes @user.google_accounts, google_account
  end

  test "active scope should exclude archived users" do
    active_user = users(:one)
    archived_user = User.create!(
      email: "archived@example.com",
      password: "password",
      name: "Archived User",
      archived_at: Time.current
    )

    active_users = User.active
    assert_includes active_users, active_user
    assert_not_includes active_users, archived_user
  end

  test "from_omniauth should find existing user by email" do
    @user.save!
    auth = OpenStruct.new(
      info: OpenStruct.new(email: @user.email, name: "Updated Name"),
      uid: "123456"
    )

    found_user = User.from_omniauth(auth)
    assert_equal @user, found_user
  end

  test "from_omniauth should create new user when email not found" do
    auth = OpenStruct.new(
      info: OpenStruct.new(email: "new@example.com", name: "New User"),
      uid: "123456"
    )

    assert_difference("User.count") do
      User.from_omniauth(auth)
    end
  end
end
