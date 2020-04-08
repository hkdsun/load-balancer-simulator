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
      job.on_tick(utilization)
    end
  end

  def work_on(job)
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
