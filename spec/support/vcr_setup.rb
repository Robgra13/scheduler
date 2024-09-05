require 'vcr'
require 'webmock/rspec'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = true

  # Filter out sensitive data like API keys or OAuth tokens
  config.filter_sensitive_data('<GOOGLE_CLIENT_ID>') { ENV['GOOGLE_CLIENT_ID'] }
  config.filter_sensitive_data('<GOOGLE_CLIENT_SECRET>') { ENV['GOOGLE_CLIENT_SECRET'] }
  config.filter_sensitive_data('<GOOGLE_ACCESS_TOKEN>') { ENV['GOOGLE_ACCESS_TOKEN'] }
  config.filter_sensitive_data('<GOOGLE_REFRESH_TOKEN>') { ENV['GOOGLE_REFRESH_TOKEN'] }
end
