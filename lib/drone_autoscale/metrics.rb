require 'aws-sdk-cloudwatch'
require 'aws-sdk-autoscaling'

require_relative 'api'

class Metrics
  attr_reader :api, :autoscaling_instances, :namespace, :cloudwatch, :enable_office_hours

  def initialize(api,
    autoscaling_instances:,
    aws_region: 'eu-west-2',
    host: 'http://localhost',
    namespace: 'Drone',
    enable_office_hours: true
  )
    @api = api
    @cloudwatch = Aws::CloudWatch::Client.new(region: aws_region)
    @namespace = namespace
    @enable_office_hours = enable_office_hours
    @autoscaling_instances = autoscaling_instances
  end

  def current_worker_count
    autoscaling_instances.length
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
