require 'sinatra'
require 'uri'
require 'net/http'
require 'json'
require_relative "secret"

ERROR = { "error" => "invalid_params", "error_description" => "Access Token not found" }.to_json

GENERAL_ERROR = { "error" => "unknown", "error_description" => "This action is not supported" }.to_json

get '/' do
  redirect to('/authenticate')
end

get '/authenticate' do
  calendar_scope = 'https://www.googleapis.com/auth/calendar'
  base_url = 'https://accounts.google.com/o/oauth2/auth'
  scope = "scope=openid profile #{calendar_scope}&"
  state = 'state=&'
  redirect_uri = 'redirect_uri=http://localhost:4567/authenticate/callback&'
  response_type = 'response_type=code&'
  client_id = "client_id=#{Secret.client_id}"

  query = scope + state + redirect_uri + response_type + client_id
  encoded_query = URI::encode(query)
  request = base_url + '?' + encoded_query

  redirect request
end

get '/authenticate/callback' do
  uri = URI.parse('https://www.googleapis.com/oauth2/v3/token')
  post_data = {
    'code' => "#{params['code']}",
    'client_id' => Secret.client_id,
    'client_secret' => Secret.client_secret,
    'redirect_uri' => 'http://localhost:4567/authenticate/callback',
    'grant_type' =>'authorization_code'
  }
  response = Net::HTTP.post_form(uri, post_data)
  response.body
end

get '/calendars' do
  unless params['accessToken']
    return ERROR
  end

  access_token = params['accessToken']
  base_url = 'https://www.googleapis.com/calendar/v3/users/me/calendarList'
  uri = URI.parse(URI.encode(base_url + "?access_token=" + access_token))
  response = Net::HTTP.get(uri)
  response_json = JSON.parse(response)

  if response_json['error']
    return response_json
  end

  calendars = []
  response_json['items'].each do |cal|
    current_calendar = {
      'id' => cal['id'],
      'title' => cal['summary'],
      'color' => cal['backgroundColor'],
      'writable' => cal['accessRole'] == 'owner' ? true : false,
      'selected' => cal['selected'],
      'timezone' => cal['timeZone']
    }
    calendars << current_calendar
  end
  { 'calendars' => calendars }.to_json
end

get '/calendars/:calendarID/events' do
  unless params['accessToken']
    return ERROR
  end

  access_token = params['accessToken']
  calendar_id = params['calendarID']
  base_url = 'https://www.googleapis.com/calendar/v3/calendars/'
  uri = URI.parse(base_url + calendar_id + '/events?access_token=' + access_token)
  response = Net::HTTP.get(uri)
  response_json = JSON.parse(response)

  if response_json['error']
    return response_json
  end

  events = []
  response_json['items'].each do |event|
    recurrence = nil
    if event['recurrence']
      recurrence = event['recurrence'][0][/FREQ=.*;/].chomp(';')
    end
    attendees = nil
    if event['attendees']
      attendees = []
      event['attendees'].each do |person|
        attendent = {
          'name' => person['displayName'],
          'emails' => [person['email']],
          'self' => person['self'],
          'rsvpStatus' => person['responseStatus']
        }
        attendees << attendent
      end
    end
    current_event = {
      'id' => event['id'],
      'status' => event['status'],
      'title' => event['summary'],
      'start' => {
        'dateTime' => event['start']['dateTime'],
        'timezone' => event['start']['timeZone']
      },
      'end' => {
        'dateTime' => event['end']['dateTime'],
        'timezone' => event['end']['timeZone']
      },
      'location' => event['location'],
      'attendees' => attendees,
      'organizer' => {
        'name' => event['organizer']['displayName'],
        'emails' => [event['organizer']['email']],
        'self' => event['organizer']['self'] ? event['organizer']['self'] : false
      },
      'editable' => event['organizer']['self'] ? true : false,
      'recurrence' => recurrence
    }
    events << current_event
  end
  { 'events' => events }.to_json
end

not_found do
  redirect to('/')
end

error do
  GENERAL_ERROR
end
