require 'aws-sdk-cloudwatch'
require 'json'
require 'httparty'

class Server
  attr_reader :host, :drone_api_token, :namespace, :client

  def initialize(
    aws_region: 'eu-west-1',
    host: 'http://localhost',
    namespace: 'Drone',
    drone_api_token: nil
  )
    abort("Error: must provide Drone API token") if drone_api_token.nil?
    @client = Aws::CloudWatch::Client.new(region: aws_region)
    @host = host
    @namespace = namespace
    @drone_api_token = drone_api_token
  end

  def api_stats
    api_url = "#{host}/api/info/queue"
    headers = { Authorization: drone_api_token }
    result = JSON.parse(HTTParty.get(api_url, headers: headers).body)
    result['stats']
  end

  def idle_workers
    api_stats['worker_count']
  end

  def pending_jobs
    api_stats['pending_count']
  end

  def running_jobs
    api_stats['running_count']
  end

  def total_jobs
    pending_jobs + running_jobs
  end

  def add_metrics(metrics = {})
    # metrics should be hash of names and values
    metric_array = []
    metrics.each do |name, value|
      metric_array << {
        metric_name: name.to_s,
        timestamp: Time.now,
        value: value,
        unit: 'Count',
        storage_resolution: 1
      }
    end

    client.put_metric_data(
      namespace: namespace,
      metric_data: metric_array
    )

    metrics.each do |name, value|
      Logger.new(STDOUT).info "#{namespace}: #{name} -> #{value}"
    end
    # return true if we get to the end without errors
    true
  end

  def run
    metrics = {
      IdleWorkers: idle_workers,
      RunningJobs: running_jobs,
      PendingJobs: pending_jobs,
      TotalJobs: total_jobs
    }

    add_metrics(metrics)
  end
end
