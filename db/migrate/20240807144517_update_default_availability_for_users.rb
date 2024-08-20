class UpdateDefaultAvailabilityForUsers < ActiveRecord::Migration[7.0]
  def up
    change_column_default :users, :availability, {
      "monday" => {"start" => "08:00", "end" => "17:30"},
      "tuesday" => {"start" => "08:00", "end" => "17:30"},
      "wednesday" => {"start" => "08:00", "end" => "17:30"},
      "thursday" => {"start" => "08:00", "end" => "17:30"},
      "friday" => {"start" => "08:00", "end" => "17:30"},
      "saturday" => {"start" => nil, "end" => nil},
      "sunday" => {"start" => nil, "end" => nil}
    }
  end

  def down
    change_column_default :users, :availability, {}
  end
end
