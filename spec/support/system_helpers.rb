module SystemHelpers
  # Sign in a user for system tests
  # With rack_test driver, this is fast enough going through the UI
  def sign_in(user, password: 'password')
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: password
    click_button "Sign in"
  end

  # Sign out a user in system tests
  def sign_out
    visit destroy_user_session_path
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system
end
