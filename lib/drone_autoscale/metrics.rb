require 'aws-sdk-autoscaling'
require 'aws-sdk-cloudwatch'
require 'json'
require 'httparty'

class Metrics
  attr_reader :host, :drone_api_token, :namespace, :cloudwatch, :asg, :group_name_query, :enable_office_hours

  def initialize(
    aws_region: 'eu-west-1',
    drone_api_token: nil,
    group_name_query: 'drone-agent',
    host: 'http://localhost',
    namespace: 'Drone',
    enable_office_hours: true
  )
    raise StandardError.new("Must provide Drone API token") if drone_api_token.nil?
    @cloudwatch = Aws::CloudWatch::Client.new(region: aws_region)
    @asg = Aws::AutoScaling::Client.new(region: aws_region)
    @host = host
    @namespace = namespace
    @drone_api_token = drone_api_token
    @group_name_query = group_name_query
    @enable_office_hours = enable_office_hours
  end

  def api
    api_url = "#{host}/api/queue"
    headers = { Authorization: drone_api_token }
    JSON.load(HTTParty.get(api_url, headers: headers).body)
  end

  def current_worker_count
    asg.describe_auto_scaling_instances.auto_scaling_instances.select {|s| s.auto_scaling_group_name =~ /^#{group_name_query}.*$/ && s.lifecycle_state =~ /^InService|Pending$/ }.length
  end

  def idle_workers
    idle = current_worker_count - total_jobs
    return 0 if idle < 0
    idle
  end

  def office_hours
    return true unless enable_office_hours

    return false if Date.today.saturday? || Date.today.sunday?

    Time.now < Time.parse('7pm') && Time.now > Time.parse('7am')
  end

  def required_workers
    # If there is more than 1 pending jobs, return the amount
    # for rapid scaling up
    return pending_jobs if pending_jobs >= 1

    if office_hours
      # There are no idle workers, create one
      if idle_workers.zero?
        return 1
      # Remove all idle workers except one if there is more than one
      elsif idle_workers > 1
        return -idle_workers + 1
      end
    else
      # If there is an idle worker, return the idle workers we wish to remove
      return -idle_workers if idle_workers.positive?
    end

    # Do nothing by default
    0
  end

  def pending_jobs
    api.select { |a| a['status'] == 'pending' }.length
  end

  def running_jobs
    api.select { |a| a['status'] == 'running' }.length
  end

  def total_jobs
    api.length
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

    cloudwatch.put_metric_data(
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
      RequiredWorkers: required_workers,
      RunningJobs: running_jobs,
      PendingJobs: pending_jobs,
      TotalJobs: total_jobs
    }

    add_metrics(metrics)
  end
end
