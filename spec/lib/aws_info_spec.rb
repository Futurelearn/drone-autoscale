require 'spec_helper'
require 'webmock/rspec'

require 'drone_autoscale/aws_info'

RSpec.describe AwsInfo do
  let(:host) { 'http://169.254.169.254/latest/meta-data/instance-id' }
  let(:instance_id) { 'i-0ffd65175f5ef1d5d' }

  let(:asg_client) { double(:asg_client) }

  before(:each) do
    allow(Aws::AutoScaling::Client).to receive(:new).and_return(asg_client)
    allow(asg_client).to receive(:describe_auto_scaling_groups).and_return(
      'auto_scaling_groups' => [
        { 'auto_scaling_group_name' => 'my-scaling-group-foo' },
        { 'auto_scaling_group_name' => 'my-favourite-cat-is-bella' }
      ]
    )
  end

  subject { described_class.new(group_name_query: 'bella') }

  describe '#instance_id' do
    before do
      stub_request(:get, host).to_return(body: instance_id)
    end

    it 'returns ID of EC2 instance' do
      result = subject.instance_id
      expect(result).to match(instance_id)
    end
  end

  describe '#autoscaling_groups' do
    before do
    end

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
end
