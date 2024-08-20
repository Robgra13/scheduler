class AddAvailabilityToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :availability, :jsonb, default: {}
  end
end
