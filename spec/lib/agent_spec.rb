require 'spec_helper'
require 'webmock/rspec'

require 'drone_autoscale/agent'

RSpec.describe Agent do
  let(:host) { "http://localhost:3000" }
  let(:endpoint) { "#{host}/varz" }

  let(:awsinfo) { double(:awsinfo) }
  let(:asg_client) { double(:asg_client) }
  let(:asg_instance) { double(:asg_instance) }

  before do
    allow(AwsInfo).to receive(:new).and_return(awsinfo)
    allow(Aws::AutoScaling::Client).to receive(:new).and_return(asg_client)
    allow(Aws::AutoScaling::Instance).to receive(:new).and_return(asg_instance)

    allow(awsinfo).to receive(:instance_id).and_return(
      'i-0ffd65175f5ef1d5d'
    )
    allow(awsinfo).to receive(:autoscaling_group_name).and_return('drone-agent')

  end


  subject { described_class.new }

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

  describe '#enable_instance_protection' do
    before do
      allow(asg_client).to receive(:set_instance_protection).and_return(Struct.new)
    end

    it 'should set instance protection to true' do
    end
  end

  describe '#disable_instance_protection' do
    before do
      allow(asg_client).to receive(:set_instance_protection).and_return(Struct.new)
    end

    it 'should set instance protection to false' do
    end
  end
end
