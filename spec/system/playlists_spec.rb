require "rails_helper"

RSpec.describe "Playlists", type: :system do
  let(:user) { create(:user) }
  let(:playlist) { create(:playlist, user: user) }

  before do
    sign_in user
  end

  it "visiting the index" do
    visit playlists_url
    expect(page).to have_content "Playlists"
  end

  it "visiting new playlist page" do
    visit new_playlist_url
    expect(page).to have_field "Name"
    expect(page).to have_field "Description"
  end

  it "visiting edit playlist page" do
    visit edit_playlist_url(playlist)
    expect(page).to have_field "Name"
    expect(page).to have_field "Description"
  end

  it "showing a playlist" do
    visit playlist_url(playlist)
    expect(page).to have_content playlist.name
  end
end
