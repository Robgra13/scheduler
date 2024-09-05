require 'google/apis/calendar_v3'
require 'google/api_client/client_secrets'
TimeSlot = Data.define(:start, :end)

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

    calendar_events = service.list_events(calendar_id,
                                          max_results: 10,
                                          single_events: true,
                                          order_by: 'startTime',
                                          time_min: Time.current.iso8601)
    calendar_events.items.each.map do |event|
      {
        start: event.start.date_time || event.start.date,
        end: event.end.date_time || event.end.date,
        summary: event.summary,
        calendar_name: calendar_id,
        event_type: determine_event_type(calendar_id)
      }
    end
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

    availability.each_with_object({}) do |(day, times), free_slots|
      day_number = day_to_cwday(day)
      available_start, available_end = calculate_day_times(day_number, times)

      if events.any?
        day_events = filter_events_for_day(events, day_number)
        day_slots = find_free_slots_within_day(day_events, available_start, available_end)
        free_slots[day] = day_slots
      else
        free_slots[day] = [TimeSlot.new(available_start, available_end )]
      end
    end
  end

  def create_event(summary, start_time, end_time, attendees)
    free_slots = list_free_slots(@current_user)
    day = Date::DAYNAMES[start_time.wday].downcase
    available = free_slots[day]&.any? do |slot|
      start_time >= slot.start && end_time <= slot.end
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
      access_token: @current_user.token || ENV['GOOGLE_ACCESS_TOKEN'],
      refresh_token: @current_user.refresh_token || ENV['GOOGLE_REFRESH_TOKEN'],
      expires_at: @current_user.expires_at || Time.now + 1.hour
    )

    auth_client
  end

  def determine_event_type(calendar_summary)
    calendar_summary.downcase.include?("work") ? "Work" : "Personal"
  end

  def day_to_cwday(day)
    Date::DAYNAMES.index(day.capitalize) + 1
  end

  def calculate_day_times(day_number, times)
    start_of_day = Time.now.beginning_of_week + (day_number -1).days
    available_start = Time.parse("#{start_of_day.to_date} #{times['start']}")
    available_end = Time.parse("#{start_of_day.to_date} #{times['end']}")
    [available_start, available_end]
  end

  def filter_events_for_day(events, day_number)
    events.select { |e| e[:start].to_date.cwday == day_number }.sort_by! { |e| e[:start] }
  end

  def find_free_slots_within_day(day_events, available_start, available_end)
    free_slots = []
    previous_end = available_start
    day_events.each do |event|
      if event[:start] > previous_end
        free_slots << TimeSlot.new(previous_end, event[:start])
      end
      previous_end = [previous_end, event[:end]].max
    end

    add_remaining_free_time(free_slots, previous_end, available_end)
    free_slots
  end

  def add_remaining_free_time(free_slots, previous_end, available_end)
    if previous_end < available_end
      free_slots << TimeSlot.new(previous_end, available_end )
    end
  end

end
