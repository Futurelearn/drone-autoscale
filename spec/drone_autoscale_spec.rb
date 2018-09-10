require 'spec_helper'
require 'webmock/rspec'

require 'drone_autoscale'

RSpec.describe DroneAutoScale do
  describe '#agent' do
    it 'should exit when endpoints are unavailable' do
      WebMock.allow_net_connect!
      expect { described_class.start(['agent']) }.to raise_exception(SystemExit)
      WebMock.disable_net_connect!
    end
  end

  describe '#server' do
    it 'should exit when endpoints are unavailable' do
      WebMock.allow_net_connect!
      expect { described_class.start(['server']) }.to raise_exception(SystemExit)
      WebMock.disable_net_connect!
    end
  end
end
