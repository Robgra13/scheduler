class User < ApplicationRecord

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: %i[google_oauth2]

  store :availability, accessors: [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday], coder: JSON
  validates :availability, presence: true
  after_initialize :set_default_availability, if: :new_record?

  def self.from_omniauth(access_token)
    data = access_token.info
    user = User.where(email: data['email']).first

    unless user
      user = User.create(
        email: data['email'],
        password: Devise.friendly_token[0, 20]
      )
    end

    user.update(
      provider: access_token.provider,
      uid: access_token.uid,
      token: access_token.credentials.token,
      refresh_token: access_token.credentials.refresh_token,
      expires_at: Time.at(access_token.credentials.expires_at)
    )
    user
  end

  def update_tokens(auth)
    self.token = auth.credentials.token
    self.refresh_token = auth.credentials.refresh_token
    self.expires_at = Time.at(auth.credentials.expires_at)
    save
  end

  def set_default_availability
    self.availability = {
      "monday" => {"start" => "08:00", "end" => "17:30"},
      "tuesday" => {"start" => "08:00", "end" => "17:30"},
      "wednesday" => {"start" => "08:00", "end" => "17:30"},
      "thursday" => {"start" => "08:00", "end" => "17:30"},
      "friday" => {"start" => "08:00", "end" => "17:30"},
      "saturday" => {"start" => nil, "end" => nil},
      "sunday" => {"start" => nil, "end" => nil}
    }
  end
end
