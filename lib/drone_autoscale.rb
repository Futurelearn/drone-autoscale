require 'drone-autoscale/agent'
require 'drone-autoscale/server'

class DroneAutoScale
  def run(mode)
    case mode
    when 'agent'
      Agent.new.run
    when 'server'
      Server.new.run
    end
  end
end
