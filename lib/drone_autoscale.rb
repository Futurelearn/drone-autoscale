require 'optimist'

require_relative 'drone_autoscale/api'
require_relative 'drone_autoscale/instance_protection'
require_relative 'drone_autoscale/metrics'

class DroneAutoScale
  def self.opts
    Optimist::options do
      opt :aws_region, "AWS region", type: :string, default: ENV['DRONE_AUTOSCALE_AWS_REGION'] || 'eu-west-2'
      opt :drone_api_token, "API token used to authenticate with Drone", type: :string, default: ENV['DRONE_AUTOSCALE_API_TOKEN']
      opt :enable_office_hours, "Set to 0 workers overnight", default: ENV['DRONE_AUTOSCALE_ENABLE_OFFICE_HOURS'] || true
      opt :group_name_query, "Name or pattern of the Drone worker autoscaling group", type: :string, default: ENV['DRONE_AUTOSCALE_GROUP_NAME_QUERY'] || 'drone-agent'
      opt :host, "Drone server endpoint", type: :string, default: ENV['DRONE_AUTOSCALE_HOST'] || 'http://localhost'
      opt :namespace, "Cloudwatch namespace to add metrics to", type: :string, default: ENV['DRONE_AUTOSCALE_NAMESPACE'] || 'Drone'
      opt :polling_time, "How often to poll the API", type: :string, default: ENV['DRONE_AUTOSCALE_POLLING_TIME'] || "5"
    end
  end

  def self.api
    API.new(drone_api_token: opts[:drone_api_token], host: opts[:host]).queue
  end

  def self.daemon
    loop do
      begin
        api_result = api

        InstanceProtection.new(api_result,
          aws_region: opts[:aws_region],
          group_name_query: opts[:group_name_query],
        ).run

        Metrics.new(api_result,
          aws_region: opts[:aws_region],
          namespace: opts[:namespace],
          enable_office_hours: opts[:enable_office_hours]
        ).run

      rescue => e
        Logger.new(STDERR).error e.to_s
        abort
      end
      sleep(opts[:polling_time].to_i)
    end
  end
end
