require File.join(File.dirname(__FILE__), '..', 'app.rb')
require File.join(File.dirname(__FILE__), '..', 'secret.rb')
require 'rack/test'
require 'json'
require 'yaml'

RSpec.configure do |config|
  config.include Rack::Test::Methods
end

def app
  Sinatra::Application
end

describe 'Calendar Proxy' do
  include Rack::Test::Methods
  access_token = Secret.access_token

  it 'root should redirect to /authenticate' do
    get '/'
    expect(last_response).to be_redirect
    expect(last_response.location).to include('/authenticate')
  end

  it '/calendars should return calenders' do
    get '/calendars', {:accessToken => access_token}
    response = JSON.parse(last_response.body)
    expect(response.keys).to contain_exactly('calendars')
    expect(response['calendars'][0].keys).to contain_exactly('id', 'title', 'color',
                                                             'writable', 'selected', 'timezone')
  end

  it 'should fail on /calendars with an invalid access token' do
    get '/calendars', {:accessToken => 'badToken'}
    # Google returns a string representation of an array for this error
    response_array = eval(last_response.body)
    expect(response_array[0]).to eq('error')
  end

  it 'should fail on /calendars without a access token' do
    get '/calendars'
    response = JSON.parse(last_response.body)
    @expected = {
      'error' => 'invalid_params',
      'error_description' => 'Access Token not found'
    }
    expect(response).to eq(@expected)
  end

  it '/calendars/:id/events should return events' do
    get "/calendars/reggiemontilus%40gmail.com/events", {:accessToken => access_token}
    response = JSON.parse(last_response.body)
    expect(response.keys).to contain_exactly('events')
    expect(response['events'][0].keys).to contain_exactly('id', 'status', 'title',
                                                          'start', 'end', 'location',
                                                          'attendees', 'organizer',
                                                          'editable', 'recurrence')
  end

  it 'should fail on /calendars/:id/events with an invalid access token' do
    get "/calendars/reggiemontilus%40gmail.com/events", {:accessToken => 'badToken'}
    # Google returns a string representation of an array for this error
    response_array = eval(last_response.body)
    expect(response_array[0]).to eq('error')
  end

  it 'should fail on /calendars/:id/events without a access token' do
    get '/calendars/reggiemontilus%40gmail.com/events'
    response = JSON.parse(last_response.body)
    @expected = {
      'error' => 'invalid_params',
      'error_description' => 'Access Token not found'
    }
    expect(response).to eq(@expected)
  end

  it '/events should fail with invalid calendar id' do
    get "/calendars/badId/events", {:accessToken => access_token}
    # Google returns a string representation of an array for this error
    response_array = eval(last_response.body)
    expect(response_array[0]).to eq('error')
  end
end
