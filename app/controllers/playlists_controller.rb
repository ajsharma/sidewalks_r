# Controller for managing user playlists.
# Handles CRUD operations for activity playlists with proper authorization.
class PlaylistsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_playlist, only: [ :show, :edit, :update, :destroy ]
  before_action :ensure_owner, only: [ :show, :edit, :update, :destroy ]

  # Lists all active playlists for the current user
  # @return [void] Sets @playlists instance variable for view rendering
  def index
    @playlists = current_user.playlists.active.includes(:playlist_activities, :activities)
  end

  # Displays a single playlist with its activities
  # @return [void] Sets @activities instance variable for view rendering
  def show
    @activities = @playlist.ordered_activities.includes(:user)
  end

  # Renders form for creating a new playlist
  # @return [void] Sets @playlist instance variable for form rendering
  def new
    @playlist = current_user.playlists.build
  end

  # Creates a new playlist for the current user
  # @return [void] Redirects to playlist on success, renders new form on failure
  def create
    @playlist = current_user.playlists.build(playlist_params)

    if @playlist.save
      redirect_to @playlist, notice: "Playlist was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Renders form for editing an existing playlist
  # @return [void] Playlist is set by before_action and ownership is verified
  def edit
  end

  # Updates an existing playlist with new parameters
  # @return [void] Redirects to playlist on success, renders edit form on failure
  def update
    if @playlist.update(playlist_params)
      redirect_to @playlist, notice: "Playlist was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Archives a playlist (soft delete)
  # @return [void] Redirects to playlists index with success notice
  def destroy
    @playlist.archive!
    redirect_to playlists_path, notice: "Playlist was successfully archived."
  end

  private

  def set_playlist
    @playlist = current_user.playlists.active.find_by!(slug: params[:id])
  end

  def ensure_owner
    redirect_to playlists_path, alert: "Access denied." unless @playlist.user == current_user
  end

  def playlist_params
    params.require(:playlist).permit(:name, :description)
  end
end
