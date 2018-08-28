class Environment
  def env(value:, default: nil, required: false)
    value.upcase!
  end
end
