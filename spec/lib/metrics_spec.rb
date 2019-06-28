require 'spec_helper'
require 'aws-sdk-autoscaling'
require 'webmock/rspec'
require 'timecop'
require 'json'

require 'drone_autoscale/metrics'

RSpec.describe Metrics do
  let(:api_endpoint) { "http://localhost/api/queue" }
  let(:drone_api_token) { "some-fake-token" }
  let(:api_result) { File.read('spec/fixtures/files/default_api.json') }

  let(:asg) { Aws::AutoScaling::Client.new(stub_responses: true) }
  let(:cloudwatch) { double(:cloudwatch) }

  before(:each) do
    allow(Aws::CloudWatch::Client).to receive(:new).and_return(cloudwatch)
    allow(Aws::AutoScaling::Client).to receive(:new).and_return(asg)
    asg.stub_responses(:describe_auto_scaling_instances, {
      auto_scaling_instances: [
        {
          instance_id: "foo",
          auto_scaling_group_name: "drone-agent",
          availability_zone: "eu-west-2b",
          lifecycle_state: "InService",
          health_status: "HEALTHY",
          launch_configuration_name: nil,
          launch_template: nil,
          protected_from_scale_in: false
        },
        {
          instance_id: "bar",
          auto_scaling_group_name: "drone-agent",
          availability_zone: "eu-west-2c",
          lifecycle_state: "InService",
          health_status: "HEALTHY",
          launch_configuration_name: nil,
          launch_template: nil,
          protected_from_scale_in: false
        }
      ]
    })

    stub_request(:get, api_endpoint).to_return(body: api_result)
  end

  subject { described_class.new(drone_api_token: drone_api_token) }

  describe '#api' do
    it 'should contain the authorization header' do
      subject.api
      expect(WebMock).to have_requested(:get, api_endpoint).with { |request|
        expect(request.headers).to include('Authorization' => 'some-fake-token')
      }
    end

    it 'returns JSON of build queue' do
      result = subject.api
      expect(result).to eq(JSON.load(api_result))
    end
  end

  describe '#idle_workers' do
    it 'returns the number of idle workers/agents' do
      expect(subject.idle_workers).to eq(0)
    end
  end

  # This metric is used in the sense that a positive value creates a worker,
  # and a negative value removes a worker
  describe '#required_workers' do
    describe 'During office hours' do
      before do
        Timecop.freeze(Time.parse('10am'))
      end
      after do
        Timecop.return
      end

      it 'if pending jobs is 1 or more, return the number of pending jobs' do
        stub_request(:get, api_endpoint)
          .to_return(body: File.read('spec/fixtures/files/pending_api.json'))
        expect(subject.required_workers).to eq(4)
      end

      it 'if idle workers is 0, create a worker' do
        stub_request(:get, api_endpoint)
          .to_return(body: File.read('spec/fixtures/files/two_running_api.json'))
        expect(subject.required_workers).to eq(1)
      end

      it 'if there is more than 1 idle worker, remove all but one.' do
        # No jobs are running and we have 2 workers
        stub_request(:get, api_endpoint).to_return(body: "[]")
        expect(subject.required_workers).to eq(-1)
      end

      it 'If there is 1 idle worker exactly, do nothing.' do
        stub_request(:get, api_endpoint)
          .to_return(body: File.read('spec/fixtures/files/one_running_api.json'))
        expect(subject.required_workers).to eq(0)
      end
    end

    describe 'Outside of office hours' do
      before do
        Timecop.freeze(Time.parse('10pm'))
      end
      after do
        Timecop.return
      end

      it 'if there is one or more pending jobs, return the pending jobs' do
        stub_request(:get, api_endpoint).to_return(body: api_result)
        expect(subject.required_workers).to eq(2)
      end

      it 'if there is 1 or more idle workers, remove them all' do
        # 2 workers and no jobs
        stub_request(:get, api_endpoint).to_return(body: "[]")
        expect(subject.required_workers).to eq(-2)
      end

      it 'if nothing is happening, do nothing' do
        stub_request(:get, api_endpoint).to_return(body: "[]")
        asg.stub_responses(:describe_auto_scaling_instances, {
          auto_scaling_instances: []
        })
        expect(subject.required_workers).to eq(0)
      end
    end
  end

  before do
    stub_request(:get, api_endpoint).to_return(body: api_result)
  end

  describe '#pending_jobs' do
    it 'returns the number of pending jobs' do
      expect(subject.pending_jobs).to eq(2)
    end
  end

  describe '#running_jobs' do
    it 'returns the number of running jobs' do
      expect(subject.running_jobs).to eq(5)
    end
  end

  describe '#total_jobs' do
    it 'returns the number of total jobs' do
      expect(subject.total_jobs).to eq(7)
    end
  end

  describe '#run' do
    before do
      Timecop.freeze(Time.parse("10am"))
    end
    after do
      Timecop.return
    end
    let(:metrics) {{
      namespace: 'Drone',
      metric_data: [
        {
          metric_name: 'IdleWorkers',
          timestamp: Time.now,
          value: 0,
          unit: 'Count',
          storage_resolution: 1
        },
        {
          metric_name: 'RequiredWorkers',
          timestamp: Time.now,
          value: 2,
          unit: 'Count',
          storage_resolution: 1
        },
        {
          metric_name: 'RunningJobs',
          timestamp: Time.now,
          value: 5,
          unit: 'Count',
          storage_resolution: 1
        },
        {
          metric_name: 'PendingJobs',
          timestamp: Time.now,
          value: 2,
          unit: 'Count',
          storage_resolution: 1
        },
        {
          metric_name: 'TotalJobs',
          timestamp: Time.now,
          value: 7,
          unit: 'Count',
          storage_resolution: 1
        }
      ]
    }}
    it 'should put metric data for all metrics' do
      allow(cloudwatch).to receive(:put_metric_data).with(metrics)
      expect(subject.run).to eq(true)
    end
  end
end
