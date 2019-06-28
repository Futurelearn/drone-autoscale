require 'spec_helper'
require 'webmock/rspec'

require 'drone_autoscale/api'

RSpec.describe API do
  let(:host) { "http://localhost/api/queue" }
  let(:drone_api_token) { "some-fake-token" }
  let(:api_result) { File.read('spec/fixtures/files/default_api.json') }

  subject { described_class.new(drone_api_token: drone_api_token) }

  before do
    stub_request(:get, host).to_return(body: api_result)
  end

  describe '#queue' do
    it 'should contain the authorization header' do
      subject.queue
      expect(WebMock).to have_requested(:get, host).with { |request|
        expect(request.headers).to include('Authorization' => 'some-fake-token')
      }
    end

    it 'returns JSON of build queue' do
      result = subject.queue
      expect(result).to eq(JSON.load(api_result))
    end
  end
end
