require 'httparty'
require 'json'
require 'aws-sdk-autoscaling'

# Runs a single task of setting instance protection for the EC2 instance this
# service is running on.
class Agent
  attr_reader :aws_region, :host, :client, :group_name_query

  def initialize(
    host: 'http://localhost:3000',
    aws_region: 'eu-west-1',
    group_name_query: 'drone-agent'
  )
    @aws_region = aws_region
    @host = host
    @group_name_query = group_name_query
    @client = Aws::AutoScaling::Client.new(region: aws_region)
  end

  def api
    endpoint = "#{host}/varz"
    JSON.parse(HTTParty.get(endpoint))
  end

  def instance_id
    HTTParty.get('http://169.254.169.254/latest/meta-data/instance-id').body
  end

  def all_autoscaling_groups
    groups = []
    resp = client.describe_auto_scaling_groups['auto_scaling_groups']
    resp.select { |g| groups << g['auto_scaling_group_name'] }
    groups
  end

  def autoscaling_group_name
    all_autoscaling_groups.grep(Regexp.new(group_name_query)).first
  end

  def job_running?
    api['running_count'].positive?
  end

  def instance_protection_enabled?
    Aws::AutoScaling::Instance.new(
      region: aws_region,
      group_name: autoscaling_group_name,
      id: instance_id
    ).protected_from_scale_in
  end

  def enable_instance_protection
    client.set_instance_protection(
      auto_scaling_group_name: autoscaling_group_name,
      instance_ids: [instance_id],
      protected_from_scale_in: true
    )
  end

  def disable_instance_protection
    client.set_instance_protection(
      auto_scaling_group_name: autoscaling_group_name,
      instance_ids: [instance_id],
      protected_from_scale_in: false
    )
  end

  def run
    if job_running?
      if instance_protection_enabled?
        return false
      else
        enable_instance_protection
        Logger.new(STDOUT).info "Instance protection enabled on #{instance_id}"
        return true
      end
    else
      if instance_protection_enabled?
        disable_instance_protection
        Logger.new(STDOUT).info "Instance protection disabled on #{instance_id}"
        return true
      else
        return false
      end
    end
  end
end
