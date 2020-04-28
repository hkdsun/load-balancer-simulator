class Job < Node
  attr_accessor :remaining_dur, :response_handler, :first_tick, :last_tick

  def initialize(duration_ticks, response_handler)
    if duration_ticks <= 0
      raise "invalid job"
    end

    @first_tick = nil
    @last_tick = nil

    @remaining_dur = duration_ticks
    @response_handler = response_handler
  end

  def on_tick
    @remaining_dur -= 1
    return @remaining_dur == 0
  end
end
