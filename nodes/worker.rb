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

      completed = job.on_tick(utilization)

      job.response_handler.call({
        utilization: utilization,
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

  def to_s
    "Worker##{id}"
  end
end
