require 'rails_helper'
require 'webmock/rspec'

RSpec.describe GoogleCalendarService do
  let(:current_user) do
    double(
      'User',
      token: 'fake_access_token',
      refresh_token: 'fake_refresh_token',
      expires_at: Time.now + 1.hour
    )
  end

  let(:service) { GoogleCalendarService.new(current_user) }

  before do
    stub_request(:post, "https://oauth2.googleapis.com/token")
      .with(
        body: {
          grant_type: 'refresh_token',
          client_id: ENV['GOOGLE_CLIENT_ID'],
          client_secret: ENV['GOOGLE_CLIENT_SECRET'],
          refresh_token: 'fake_refresh_token'
        }
      )
      .to_return(
        status: 200,
        body: {
          access_token: 'fake_access_token',
          expires_in: 3600
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    stub_request(:get, "https://www.googleapis.com/calendar/v3/calendars/primary/events")
      .with(
        query: {
          maxResults: '10',
          orderBy: 'startTime',
          singleEvents: 'true',
          timeMin: Time.now.iso8601
        },
        headers: {
          'Authorization' => 'Bearer fake_access_token'
        }
      )
      .to_return(
        status: 200,
        body: {
          items: [{
            start: { date_time: Time.now.iso8601 },
            end: { date_time: (Time.now + 1.hour).iso8601 },
            summary: 'Test Event'
          }]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  describe '#list_events' do
    it 'returns a list of events from the Google Calendar API' do
      events = service.list_events
      expect(events).to be_an(Array)
      expect(events.first[:summary]).to eq('Test Event')
    end
  end
end
