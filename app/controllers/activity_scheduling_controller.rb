class ActivitySchedulingController < ApplicationController
  before_action :authenticate_user!

  def show
    @scheduling_service = ActivitySchedulingService.new(current_user)
    @date_range = parse_date_range
    @agenda = @scheduling_service.generate_agenda(@date_range)
  end

  def create
    @scheduling_service = ActivitySchedulingService.new(current_user)
    @date_range = parse_date_range
    @agenda = @scheduling_service.generate_agenda(@date_range)

    if params[:dry_run] != "false"
      # Dry run mode - show suggestions
      @results = @scheduling_service.create_calendar_events(@agenda.suggestions, dry_run: true)
      render :preview
    else
      # Actually create calendar events
      @results = @scheduling_service.create_calendar_events(@agenda.suggestions, dry_run: false)

      success_count = @results.count { |r| r[:status] == "created" }
      failure_count = @results.count { |r| r[:status] == "failed" }

      if failure_count == 0
        redirect_to schedule_path, notice: "Successfully created #{success_count} calendar events!"
      else
        redirect_to schedule_path, alert: "Created #{success_count} events, but #{failure_count} failed. Check your Google Calendar connection."
      end
    end
  end

  private

  def parse_date_range
    start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current
    end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : (Date.current + 2.weeks)

    start_date..end_date
  rescue ArgumentError
    Date.current..(Date.current + 2.weeks)
  end
end
