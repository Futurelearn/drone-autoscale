require 'spec_helper'
require 'webmock/rspec'

require 'drone_autoscale/agent'

RSpec.describe Agent do
  let(:ec2_metadata_host) { 'http://169.254.169.254/latest/meta-data/instance-id' }
  let(:endpoint) { "#{host}/varz" }
  let(:host) { "http://localhost:3000" }
  let(:instance_id) { 'i-0ffd65175f5ef1d5d' }

  let(:asg_client) { double(:asg_client) }
  let(:asg_instance) { double(:asg_instance) }

  before(:each) do
    allow(Aws::AutoScaling::Client).to receive(:new).and_return(asg_client)
    allow(Aws::AutoScaling::Instance).to receive(:new).and_return(asg_instance)

    allow(asg_client).to receive(:describe_auto_scaling_groups).and_return(
      'auto_scaling_groups' => [
        { 'auto_scaling_group_name' => 'my-scaling-group-foo' },
        { 'auto_scaling_group_name' => 'my-favourite-cat-is-bella' }
      ]
    )
    stub_request(:get, ec2_metadata_host).to_return(body: instance_id)
  end

  subject { described_class.new(group_name_query: 'bella') }

  describe '#api' do
    let(:varz) { {"polling_count":1,"running_count":0,"running":{}} }

    before do
      stub_request(:get, endpoint).to_return(body: JSON.dump(varz))
    end

    it 'returns JSON of /varz' do
      result = subject.api
      expect(result).to include(
        'running_count' => 0,
        'running' => {},
        'polling_count' => 1,
      )
    end
  end

  describe '#instance_id' do
    it 'returns ID of EC2 instance' do
      result = subject.instance_id
      expect(result).to match(instance_id)
    end
  end

  describe '#autoscaling_groups' do
    it 'returns an array of autoscaling groups' do
      expect(subject.all_autoscaling_groups).to eq(
        [
          'my-scaling-group-foo',
          'my-favourite-cat-is-bella'
        ]
      )
    end
  end

  describe '#autoscaling_group_name_lookup' do
    it 'returns a single result based upon a query value' do
      expect(subject.autoscaling_group_name).to eq(
        'my-favourite-cat-is-bella'
      )
    end
  end
  describe '#job_running?' do
    let(:varz) { {"polling_count":1,"running_count":0,"running":{}} }
    before do
      stub_request(:get, endpoint).to_return(body: JSON.dump(varz))
    end

    it 'returns false when running_count is 0' do
      expect(subject.job_running?).to eq(false)
    end
  end

  describe '#instance_protection_enabled?' do
    before do
      allow(asg_instance).to receive(:protected_from_scale_in).and_return(true)
    end

    it 'returns true if the instance has instance protection enabled' do
      expect(subject.instance_protection_enabled?).to eq(true)
    end
  end

  describe '#run' do
    let(:default_varz) { 
      {
        "polling_count": 1,
        "running":{}
      } 
    }
    let(:defaults) { 
      {
        auto_scaling_group_name: 'my-favourite-cat-is-bella',
        instance_ids: [instance_id]
      } 
    }

    it 'should enable instance protection if a job is running and it is not enabled' do
      stub_request(:get, endpoint).to_return(body: JSON.dump(default_varz.merge(running_count: 1)))
      allow(asg_instance).to receive(:protected_from_scale_in).and_return(false)
      allow(asg_client).to receive(:set_instance_protection).with(
        defaults.merge(protected_from_scale_in: true)
      )
      expect(subject.run).to eq(true)
    end

    it 'should disable instance protection if a job is not running and it is not disabled' do
      stub_request(:get, endpoint).to_return(body: JSON.dump(default_varz.merge(running_count: 0)))
      allow(asg_instance).to receive(:protected_from_scale_in).and_return(true)
      allow(asg_client).to receive(:set_instance_protection).with(
        defaults.merge(protected_from_scale_in: false)
      )
      expect(subject.run).to eq(true)
    end

    it 'should do nothing if job is running and instance protection already enabled' do
      stub_request(:get, endpoint).to_return(body: JSON.dump(default_varz.merge(running_count: 1)))
      allow(asg_instance).to receive(:protected_from_scale_in).and_return(true)
      allow(asg_client).to receive(:set_instance_protection).with(
        defaults.merge({protected_from_scale_in: false})
      )
      expect(subject.run).to eq(false)
    end
    
    it 'should do nothing if job is not running and instance protection already disabled' do
      stub_request(:get, endpoint).to_return(body: JSON.dump(default_varz.merge(running_count: 0)))
      allow(asg_instance).to receive(:protected_from_scale_in).and_return(false)
      allow(asg_client).to receive(:set_instance_protection).with(
        defaults.merge({protected_from_scale_in: false})
      )
      expect(subject.run).to eq(false)
    end
  end
end
