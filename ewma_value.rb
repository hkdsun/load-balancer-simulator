class EWMAValue
  # Exponential Moving Average: https://en.wikipedia.org/wiki/Moving_average
  #
  # The average starts at its first sampled value and decays to half its value every half_life_seconds
  # The caller is responsible for passing in the time delta
  attr_reader :average

  def initialize(half_life_seconds, initial_value=0)
    @tau = 1.44 * half_life_seconds # see Half-Life section in https://en.wikipedia.org/wiki/Exponential_decay
    @average = initial_value
    @last_updated = now
  end

  def add_sample(value, time_diff_seconds=(now-@last_updated))
    weight = Math.exp(-time_diff_seconds/@tau)
    @average = (1 - weight) * value + weight * @average
    @last_updated = now
    return @average
  end

  private

  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_second)
  end
end
