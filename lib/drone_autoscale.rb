require 'thor'

require_relative 'drone_autoscale/agent'
require_relative 'drone_autoscale/server'

class DroneAutoScale < Thor
  package_name 'drone-autoscale'
  desc 'agent', 'Set current EC2 InstanceProtection status'
  method_option :host, default: ENV['DRONE_AUTOSCALE_HOST'] || 'http://localhost:3000'
  method_option :aws_region, default: ENV['DRONE_AUTOSCALE_AWS_REGION'] || 'eu-west-1'
  method_option :group_name_query, default: ENV['DRONE_AUTOSCALE_GROUP_NAME_QUERY'] || 'drone-agent'
  method_option :polling_time, type: :numeric, default: ENV['DRONE_AUTOSCALE_POLLING_TIME'] || '20'
  def agent
    Logger.new(STDOUT).info "Agent: started"
    loop do
      Agent.new(
        host: options[:host],
        aws_region: options[:aws_region],
        group_name_query: options[:group_name_query]
      ).run
      sleep(options[:polling_time].to_i)
    end
  end

  desc 'server', 'Publish Drone server metrics to AWS CloudWatch'
  method_option :host, default: ENV['DRONE_AUTOSCALE_HOST'] || 'http://localhost'
  method_option :aws_region, default: ENV['DRONE_AUTOSCALE_AWS_REGION'] || 'eu-west-1'
  method_option :namespace, default: ENV['DRONE_AUTOSCALE_NAMESPACE'] || 'Drone'
  method_option :drone_api_token, default: ENV['DRONE_AUTOSCALE_API_TOKEN']
  method_option :polling_time, type: :numeric, default: ENV['DRONE_AUTOSCALE_POLLING_TIME'] || '20'
  def server
    Logger.new(STDOUT).info "Server: started"
    loop do
      Server.new(
        host: options[:host],
        aws_region: options[:aws_region],
        namespace: options[:namespace],
        drone_api_token: options[:drone_api_token]
      ).run
      sleep(options[:polling_time].to_i)
    end
  end
end
