class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
    current_user_calendar_service = GoogleCalendarService.new(current_user)
    @user_events = current_user_calendar_service.list_events

    robert_email = 'robertgradowski00@gmail.com'
    robert_calendar_service = GoogleCalendarService.new(current_user, robert_email)
    @robert_events = robert_calendar_service.list_events

    robert = User.find_by(email: robert_email)
    @free_slots = robert_calendar_service.list_free_slots(robert)
  end
end
