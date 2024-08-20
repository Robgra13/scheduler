class UpdateAvailabilityForExistingUsers < ActiveRecord::Migration[7.0]
  def up
    User.find_each do |user|
      unless user.availability.present?
        user.update(availability: {
          "monday" => {"start" => "08:00", "end" => "17:30"},
          "tuesday" => {"start" => "08:00", "end" => "17:30"},
          "wednesday" => {"start" => "08:00", "end" => "17:30"},
          "thursday" => {"start" => "08:00", "end" => "17:30"},
          "friday" => {"start" => "08:00", "end" => "17:30"},
          "saturday" => {"start" => nil, "end" => nil},
          "sunday" => {"start" => nil, "end" => nil}
        })
      end
    end
  end
end
