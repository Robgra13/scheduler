require 'google/apis/calendar_v3'
require 'google/api_client/client_secrets'

class GoogleCalendarService

  def initialize(current_user, target_email = nil)
    @current_user = current_user
    @target_email = target_email
    @client = initialize_google_client

  end

  def list_events
    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = @client

    calendar_id = @target_email || 'primary'
    events = []

    calendar_events = service.list_events(calendar_id,
                                          max_results: 10,
                                          single_events: true,
                                          order_by: 'startTime',
                                          time_min: Time.now.iso8601)
    calendar_events.items.each do |event|
      events << {
        start: event.start.date_time || event.start.date,
        end: event.end.date_time || event.end.date,
        summary: event.summary,
        calendar_name: calendar_id,
        event_type: determine_event_type(calendar_id)
      }
    end

    events
  end


  def available_for_booking?(start_time, end_time)
    events = list_events

    # Check if any event overlaps with the proposed time slot
    events.none? do |event|
      event[:start] < end_time && event[:end] > start_time
      end
  end


  def list_free_slots(user)
    events = list_events
    availability = user.availability

    free_slots = {}

    availability.each do |day, times|
      start_of_day = Time.now.beginning_of_week + day_index(day).days
      available_start = Time.parse("#{start_of_day.to_date} #{times['start']}")
      available_end = Time.parse("#{start_of_day.to_date} #{times['end']}")

      if events.any?
        # Filter events for the current day
        day_events = events.select { |e| e[:start].to_date == start_of_day.to_date }
        day_events.sort_by! { |e| e[:start] }
        previous_end = available_start

        # Find gaps between events
        day_events.each do |event|
          if event[:start] > previous_end
            free_slots[day] ||= []
            free_slots[day] << { start: previous_end, end: event[:start] }
          end
          previous_end = [previous_end, event[:end]].max
        end

        # Check if there is free time after the last event until end_of_day
        if previous_end < available_end
          free_slots[day] ||= []
          free_slots[day] << { start: previous_end, end: available_end }
        end
      else
        # If there are no events, the entire availability window is free
        free_slots[day] = [{ start: available_start, end: available_end }]
      end
    end
    free_slots
  end

  def create_event(summary, start_time, end_time, attendees)
    # Check for free slots before creating the event
    free_slots = list_free_slots(@current_user)

    # Determine the day of the week for the requested start time
    day = start_time.strftime("%A").downcase

    # Find if the start_time and end_time fall within any free slots
    available = free_slots[day]&.any? do |slot|
      start_time >= slot[:start] && end_time <= slot[:end]
    end

    if available
      service = Google::Apis::CalendarV3::CalendarService.new
      service.authorization = @client

      event = Google::Apis::CalendarV3::Event.new(
        summary: summary,
        start: Google::Apis::CalendarV3::EventDateTime.new(
          date_time: start_time.in_time_zone('Europe/Warsaw').iso8601,
          time_zone: 'Europe/Warsaw' # Explicitly setting the time zone
        ),
        end: Google::Apis::CalendarV3::EventDateTime.new(
          date_time: end_time.in_time_zone('Europe/Warsaw').iso8601,
          time_zone: 'Europe/Warsaw' # Explicitly setting the time zone
        ),
        attendees: attendees.map { |attendee| Google::Apis::CalendarV3::EventAttendee.new(email: attendee[:email]) }
      )
      result = service.insert_event('primary', event, send_updates: 'all')
      result
    else
      nil
    end
  end


  private



  def initialize_google_client
    client_secrets = Google::APIClient::ClientSecrets.new({
      "web" => {
        "client_id" => CONFIG[:google_client_id],
        "client_secret" => CONFIG[:google_client_secret],
        "redirect_uris" => [CONFIG[:app_host]],
        "auth_uri" => "https://accounts.google.com/o/oauth2/auth",
        "token_uri" => "https://oauth2.googleapis.com/token"
      }
    })

    auth_client = client_secrets.to_authorization
    auth_client.update!(
      scope: 'https://www.googleapis.com/auth/calendar.readonly',
      access_token: @current_user.token,
      refresh_token: @current_user.refresh_token,
      expires_at: @current_user.expires_at
    )

    auth_client
  end

  def determine_event_type(calendar_summary)
    calendar_summary.downcase.include?("work") ? "Work" : "Personal"
  end

  def day_index(day)
    case day
    when "monday"    then 0
    when "tuesday"   then 1
    when "wednesday" then 2
    when "thursday"  then 3
    when "friday"    then 4
    else 0
    end
  end
end
