require 'rails_helper'

RSpec.describe GoogleCalendarService do
  let(:current_user) { double('User', token: 'test_token', refresh_token: 'test_refresh_token', expires_at: Time.now + 1.hour) }
  let(:target_email) { 'test@example.com' }
  let(:service) { GoogleCalendarService.new(current_user, target_email) }

  it 'initializes with a current_user and target_email' do
    expect(service.instance_variable_get(:@current_user)).to eq(current_user)
    expect(service.instance_variable_get(:@target_email)).to eq(target_email)
  end

  it 'initializes without a target_email' do
    service_without_email = GoogleCalendarService.new(current_user)
    expect(service_without_email.instance_variable_get(:@current_user)).to eq(current_user)
    expect(service_without_email.instance_variable_get(:@target_email)).to be_nil
  end

  it 'initializes the @client with the Google API Client' do
    expect(service.instance_variable_get(:@client)).to be_a_kind_of(Signet::OAuth2::Client)
  end

  describe '#list_events' do
    let(:mock_calendar_service) { double('Google::Apis::CalendarV3::CalendarService') }
    let(:mock_event) {
      double('Google::Apis::CalendarV3::Event',
        start: double('EventDateTime', date_time: '2024-08-20T10:00:00Z'),
        end: double('EventDateTime', date_time: '2024-08-20T11:00:00Z'),
        summary: 'Test Event')
    }
    let(:mock_events) {
      double('Google::Apis::CalendarV3::Events',
        items: [mock_event, double('Google::Apis::CalendarV3::Event',
        start: double('EventDateTime', date_time: '2024-08-21T14:00:00Z'),
        end: double('EventDateTime', date_time: '2024-08-21T15:00:00Z'),
        summary: 'Another Test Event')])
    }

    before do
      allow(Google::Apis::CalendarV3::CalendarService).to receive(:new).and_return(mock_calendar_service)
      allow(mock_calendar_service).to receive(:authorization=)
      allow(mock_calendar_service).to receive(:list_events).and_return(mock_events)
    end

    it 'returns a list of events with correct attributes' do
      events = service.list_events

      expect(events).to be_an(Array)
      expect(events.size).to eq(2)

      expect(events[0]).to eq({
        start: '2024-08-20T10:00:00Z',
        end: '2024-08-20T11:00:00Z',
        summary: 'Test Event',
        calendar_name: target_email,
        event_type: 'Personal' # Assuming target_email does not include "work" in this case
      })

      expect(events[1]).to eq({
        start: '2024-08-21T14:00:00Z',
        end: '2024-08-21T15:00:00Z',
        summary: 'Another Test Event',
        calendar_name: target_email,
        event_type: 'Personal' # Assuming target_email does not include "work" in this case
      })
    end
  end

  describe '#available_for_booking?' do
    let(:start_time) { Time.zone.parse('2024-08-20 09:00') }
    let(:end_time) { Time.zone.parse('2024-08-20 10:00') }

    context 'when there are no events' do
      before do
        allow(service).to receive(:list_events).and_return([])
      end

      it 'returns true' do
        expect(service.available_for_booking?(start_time, end_time)).to be true
      end
    end

    context 'when there is an overlapping event' do
      before do
        allow(service).to receive(:list_events).and_return([
          { start: Time.zone.parse('2024-08-20 08:30'), end: Time.zone.parse('2024-08-20 09:30') }
        ])
      end

      it 'returns false' do
        expect(service.available_for_booking?(start_time, end_time)).to be false
      end
    end

    context 'when there are no overlapping events' do
      before do
        allow(service).to receive(:list_events).and_return([
          { start: Time.zone.parse('2024-08-20 07:00'), end: Time.zone.parse('2024-08-20 08:00') },
          { start: Time.zone.parse('2024-08-20 11:00'), end: Time.zone.parse('2024-08-20 12:00') }
        ])
      end

      it 'returns true' do
        expect(service.available_for_booking?(start_time, end_time)).to be true
      end
    end
  end

  describe '#create_event' do
    let(:summary) { 'Test Event' }
    let(:start_time) { Time.zone.parse('2024-08-20 09:00') }
    let(:end_time) { Time.zone.parse('2024-08-20 10:00') }
    let(:attendees) { [{ email: 'attendee1@example.com' }, { email: 'attendee2@example.com' }] }

    let(:mock_calendar_service) { double('Google::Apis::CalendarV3::CalendarService') }
    let(:mock_event) { double('Google::Apis::CalendarV3::Event', id: 'event_id') }

    before do
      allow(Google::Apis::CalendarV3::CalendarService).to receive(:new).and_return(mock_calendar_service)
      allow(mock_calendar_service).to receive(:authorization=)
    end

    context 'when the time slot is available' do
      before do
        allow(service).to receive(:list_free_slots).and_return({
          'tuesday' => [TimeSlot.new(start_time - 1.hour, end_time + 1.hour)]
        })
        allow(mock_calendar_service).to receive(:insert_event).and_return(mock_event)
      end

      it 'creates an event and returns the result' do
        result = service.create_event(summary, start_time, end_time, attendees)
        expect(result).to eq(mock_event)
        expect(mock_calendar_service).to have_received(:insert_event).with(
          'primary',
          instance_of(Google::Apis::CalendarV3::Event),
          send_updates: 'all'
        )
      end
    end

    context 'when the time slot is not available' do
      before do
        allow(service).to receive(:list_free_slots).and_return({
          'tuesday' => [TimeSlot.new(start_time + 1.hour, end_time + 2.hours)]
        })
        allow(mock_calendar_service).to receive(:insert_event)
      end

      it 'does not create an event and returns nil' do
        result = service.create_event(summary, start_time, end_time, attendees)
        expect(result).to be_nil
        expect(mock_calendar_service).not_to have_received(:insert_event)
      end
    end

    context 'when no free slots are returned for the day' do
      before do
        allow(service).to receive(:list_free_slots).and_return({})
        allow(mock_calendar_service).to receive(:insert_event)
      end

      it 'does not create an event and returns nil' do
        result = service.create_event(summary, start_time, end_time, attendees)
        expect(result).to be_nil
        expect(mock_calendar_service).not_to have_received(:insert_event)
      end
    end
  end
end
