require 'httparty'
require 'json'

class API
  attr_reader :host, :drone_api_token

  def initialize(
    drone_api_token: nil,
    host: 'http://localhost'
  )
    raise StandardError.new("Must provide Drone API token") if drone_api_token.nil?
    @host = host
    @drone_api_token = drone_api_token
  end

  def queue
    api_url = "#{host}/api/queue"
    headers = { Authorization: drone_api_token }
    JSON.load(HTTParty.get(api_url, headers: headers).body)
  end
end
