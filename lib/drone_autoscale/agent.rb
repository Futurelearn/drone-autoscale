require 'httparty'
require 'json'
require 'aws-sdk-autoscaling'

require_relative 'aws_info'

# Runs a single task of setting instance protection for the EC2 instance this
# service is running on.
class Agent
  attr_reader :aws_region, :host, :client, :asg_group, :instance_id

  def initialize(
    host: 'http://localhost:3000',
    aws_region: 'eu-west-1',
    asg_group_lookup: 'drone-agent'
  )
    @aws_region = aws_region
    @host = host
    @client = Aws::AutoScaling::Client.new(region: aws_region)
    @asg_group = AwsInfo.new(group_name_query: asg_group_lookup).autoscaling_group_name
    @instance_id = AwsInfo.new.instance_id
  end

  def api
    endpoint = "#{host}/varz"
    JSON.parse(HTTParty.get(endpoint))
  end

  def job_running?
    if api['running_count'] > 0
      true
    else
      false
    end
  end

  def instance_protection_enabled?
    begin
      Aws::AutoScaling::Instance.new(
        region: aws_region,
        group_name: asg_group,
        id: instance_id
      ).
        protected_from_scale_in
    rescue Aws::AutoScaling::Errors::ServiceError => e
      abort(e)
    end
  end

  def enable_instance_protection
    begin
      client.set_instance_protection({
        auto_scaling_group_name: asg_group,
        instance_ids: [instance_id],
        protected_from_scale_in: true
      })
    rescue Aws::AutoScaling::Errors::ServiceError => e
      abort(e)
    end
  end

  def disable_instance_protection
    begin
      client.set_instance_protection({
        auto_scaling_group_name: asg_group,
        instance_ids: [instance_id],
        protected_from_scale_in: false
      })
    rescue Aws::AutoScaling::Errors::ServiceError => e
      abort(e)
    end
  end

  def run
    if job_running?
      unless instance_protection_enabled?
        enable_instance_protection
      end
    else
      if instance_protection_enabled?
        disable_instance_protection
      end
    end
  end
end
