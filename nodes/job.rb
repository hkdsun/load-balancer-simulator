class Job < Node
  attr_accessor :remaining_dur

  def initialize(duration_ticks, on_completion)
    if duration_ticks <= 0
      raise "invalid job"
    end

    @remaining_dur = duration_ticks
    @on_completion = on_completion
  end

  def on_tick(util)
    @remaining_dur -= 1
    if @remaining_dur == 0
      @on_completion.call(util)
      return true
    elsif @remaining_dur < 0
      raise "Called completed job"
    else
      false
    end
  end
end
