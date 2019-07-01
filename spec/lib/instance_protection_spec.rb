require 'spec_helper'
require 'webmock/rspec'

require 'drone_autoscale/instance_protection'

RSpec.describe InstanceProtection do
  let(:api_endpoint) { "http://localhost/api/queue" }
  let(:api_result) { File.read('spec/fixtures/files/two_running_api.json') }

  let(:asg) { Aws::AutoScaling::Client.new(stub_responses: true) }

  let(:api) { API.new(drone_api_token: 'some-fake-token').queue }

  before(:each) do
    allow(Aws::AutoScaling::Client).to receive(:new).and_return(asg)
    asg.stub_responses(:describe_auto_scaling_instances, {
      auto_scaling_instances: [
        {
          instance_id: "agent-1",
          auto_scaling_group_name: "drone-agent",
          availability_zone: "eu-west-2b",
          lifecycle_state: "InService",
          health_status: "HEALTHY",
          launch_configuration_name: nil,
          launch_template: nil,
          protected_from_scale_in: false
        },
        {
          instance_id: "agent-2",
          auto_scaling_group_name: "drone-agent",
          availability_zone: "eu-west-2c",
          lifecycle_state: "InService",
          health_status: "HEALTHY",
          launch_configuration_name: nil,
          launch_template: nil,
          protected_from_scale_in: false
        },
        {
          instance_id: "agent-3",
          auto_scaling_group_name: "drone-agent",
          availability_zone: "eu-west-2a",
          lifecycle_state: "InService",
          health_status: "HEALTHY",
          launch_configuration_name: nil,
          launch_template: nil,
          protected_from_scale_in: true
        }
      ]
    })
    asg.stub_responses(:describe_auto_scaling_groups, {
      auto_scaling_groups: [
        {
          auto_scaling_group_name: "drone-agent",
          min_size: 0,
          max_size: 10,
          desired_capacity: 3,
          availability_zones: ['eu-west-1a', 'eu-west-1b', 'eu-west-1c'],
          health_check_type: 'EC2',
          created_time: Time.now,
          default_cooldown: 300
        },
      ]
    })
    stub_request(:get, api_endpoint).to_return(body: api_result)
  end

  let(:autoscaling_instances) { Aws::AutoScaling::Client.new.describe_auto_scaling_instances.auto_scaling_instances }
  subject { described_class.new(api, autoscaling_instances: autoscaling_instances) }

  describe '#all_available_worker_ids' do
    it 'returns an array of instance IDs in the autoscaling group' do
      expect(subject.all_available_worker_ids).to eq(
        [
          'agent-1',
          'agent-2',
          'agent-3'
        ]
      )
    end
  end

  describe '#busy_worker_ids' do
    it 'returns an array of instance IDs that are currently running jobs' do
      expect(subject.busy_worker_ids).to eq(
        [
          'agent-1',
          'agent-2'
        ]
      )
    end
  end

  describe '#free_worker_ids' do
    it 'returns an array of instance IDs that are not running jobs' do
      expect(subject.free_worker_ids).to eq(['agent-3'])
    end
  end

  describe '#run' do
    it 'should enable instance protection on busy workers and disable protection on free workers' do
      expect(asg).to receive(:set_instance_protection).with(
        auto_scaling_group_name: 'drone-agent',
        instance_ids: ['agent-1', 'agent-2'],
        protected_from_scale_in: true
      )
      expect(asg).to receive(:set_instance_protection).with(
        auto_scaling_group_name: 'drone-agent',
        instance_ids: ['agent-3'],
        protected_from_scale_in: false
      )
      subject.run
    end

  end
end
