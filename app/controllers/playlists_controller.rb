class PlaylistsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_playlist, only: [:show, :edit, :update, :destroy]
  before_action :ensure_owner, only: [:show, :edit, :update, :destroy]

  def index
    @playlists = current_user.playlists.active.includes(:activities)
  end

  def show
    @activities = @playlist.ordered_activities.includes(:user)
  end

  def new
    @playlist = current_user.playlists.build
  end

  def create
    @playlist = current_user.playlists.build(playlist_params)

    if @playlist.save
      redirect_to @playlist, notice: 'Playlist was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @playlist.update(playlist_params)
      redirect_to @playlist, notice: 'Playlist was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @playlist.archive!
    redirect_to playlists_path, notice: 'Playlist was successfully archived.'
  end

  private

  def set_playlist
    @playlist = Playlist.active.find_by!(slug: params[:id])
  end

  def ensure_owner
    redirect_to playlists_path, alert: 'Access denied.' unless @playlist.user == current_user
  end

  def playlist_params
    params.require(:playlist).permit(:name, :description)
  end
end
