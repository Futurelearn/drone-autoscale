require 'spec_helper'

require 'drone_autoscale'

RSpec.describe DroneAutoScale do
  describe '#agent' do
    it 'should exit when endpoints are unavailable' do
      expect { described_class.start(['agent']) }.to raise_exception(SystemExit)
    end
  end

  describe '#server' do
    it 'should exit when endpoints are unavailable' do
      expect { described_class.start(['server']) }.to raise_exception(SystemExit)
    end
  end
end
