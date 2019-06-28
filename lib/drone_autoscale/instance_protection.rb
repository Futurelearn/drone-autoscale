require 'httparty'
require 'json'
require 'aws-sdk-autoscaling'

require_relative 'api'

class InstanceProtection
  attr_reader :api, :aws_region, :asg, :group_name_query

  def initialize(api,
    aws_region: 'eu-west-1',
    group_name_query: 'drone-agent'
  )
    @api = api
    @aws_region = aws_region
    @group_name_query = group_name_query
    @asg = Aws::AutoScaling::Client.new(region: aws_region)
  end

  def autoscaling_group_name
    asg.describe_auto_scaling_groups.auto_scaling_groups.detect {|g| g.auto_scaling_group_name =~ /^#{group_name_query}.*$/ }.auto_scaling_group_name
  end

  # List all worker instance IDs in an autoscaling group
  def all_available_worker_ids
    asg.describe_auto_scaling_instances.auto_scaling_instances.select {|s| s.auto_scaling_group_name == autoscaling_group_name && s.lifecycle_state =~ /^InService|Pending$/ }.map(&:instance_id)
  end

  def busy_worker_ids
    api.map {|x| x['machine'] }.compact
  end

  def free_worker_ids
    all_available_worker_ids - busy_worker_ids
  end

  def update_instance_protection(instance_ids, enabled)
    return if instance_ids.empty?

    if enabled
      Logger.new(STDOUT).info "Enabling instance protection on #{instance_ids.join(' ')}"
    else
      Logger.new(STDOUT).info "Disabling instance protection on #{instance_ids.join(' ')}"
    end

    asg.set_instance_protection(
      auto_scaling_group_name: autoscaling_group_name,
      instance_ids: instance_ids,
      protected_from_scale_in: enabled
    )
  end

  def run
    update_instance_protection(busy_worker_ids, true)
    update_instance_protection(free_worker_ids, false)
  end
end
