require_relative '../ewma_value'

class Worker < Node
  def initialize(id, capacity)
    super(id)
    @capacity = capacity
  end

  def on_tick
    remaining_capacity = @capacity
    in_progress.delete_if do |job|
      remaining_capacity -= 1
      if remaining_capacity <= 0
        # puts "WARN: worker overloaded"
        break false
      end

      completed = job.on_tick

      job.response_handler.call({
        utilization: ewma_util,
        latency: @tick - job.first_tick
      }) if completed

      completed
    end
  end

  def stats
    stats ||= Hash.new { {} }
  end

  def start_job(job)
    job.first_tick = @tick
    in_progress << job
  end

  def in_progress
    @in_progress ||= []
  end

  def remove_job(job)
    in_progress.delete(job)
  end

  def utilization
    in_progress.size / @capacity.to_f
  end

  def ewma_util
    @ewma_util ||= EWMAValue.new(5)

    td = @last_sampled_at == nil ? 0 : @tick-@last_sampled_at
    current_ewma = @ewma_util.add_sample(utilization, td)
    @last_sampled_at = @tick

    current_ewma
  end

  def to_s
    "Worker##{id}"
  end
end
