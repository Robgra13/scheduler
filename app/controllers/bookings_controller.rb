class BookingsController < ApplicationController
  before_action :set_robert_calendar_service, only: [:create]

  def new
    @booker_email = current_user.email
  end

  def create
    date = params[:date]
    time = params[:time]
    duration = params[:duration]

    start_time = DateTime.parse("#{date} #{time}")
    end_time = start_time + params[:duration].to_i.minutes
    summary = params[:summary]
    booker_email = params[:booker_email]
    attendees_emails = params[:attendees].to_s.split(',').map(&:strip)

    start_time = Time.zone.parse("#{date} #{time}").in_time_zone('Europe/Warsaw')
    end_time = start_time + duration.to_i.minutes

    attendees = attendees_emails.map { |email| { email: email } }
    attendees << { email: booker_email }
    attendees << { email: 'robertgradowski00@gmail.com' } unless attendees_emails.include?('robertgradowski00@gmail.com')

    event = @google_calendar_service.create_event(summary, start_time, end_time, attendees)

    if event
      flash[:notice] = "Event successfully created!"
    else
      flash[:alert] = "The selected time slot is not available or there was an error creating the event."
    end

    redirect_to root_path
  end

  private

  def set_robert_calendar_service
    robert_email = 'robertgradowski00@gmail.com'
    @google_calendar_service = GoogleCalendarService.new(current_user, robert_email)
  end
end
