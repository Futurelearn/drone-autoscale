require 'httparty'
require 'aws-sdk-autoscaling'

class AwsInfo
  attr_reader :asg_client, :group_name_query
  
  def initialize(aws_region: 'eu-west-1', group_name_query: 'drone-agent')
    @asg_client = Aws::AutoScaling::Client.new(region: aws_region)
    @group_name_query = group_name_query
  end

  def instance_id
    HTTParty.get('http://169.254.169.254/latest/meta-data/instance-id')
  end

  def all_autoscaling_groups
    groups = []
    resp = asg_client.describe_auto_scaling_groups['auto_scaling_groups']
    resp.select { |g| groups << g['auto_scaling_group_name'] }
    groups
  end

  def autoscaling_group_name
    all_autoscaling_groups.grep(Regexp.new(group_name_query)).first
  end
end
