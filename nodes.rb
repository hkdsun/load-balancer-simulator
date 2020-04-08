require_relative 'roundrobin'

class Node
  attr_accessor :id

  def initialize(id)
    @id = id
    @tick = 0
  end

  def tick
    @tick += 1
    on_tick
  end

  def on_tick
    raise NotImplementedError
  end
end

class Job
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

class Worker < Node
  def initialize(id, capacity)
    super(id)
    @capacity = capacity
  end

  def on_tick
    remaining_capacity = @capacity
    in_progress.delete_if do |job|
      remaining_capacity -= 1
      break false if remaining_capacity <= 0
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

class LB < Node
  def initialize(id, upstreams, jobs_per_tick, job_dur)
    super(id)
    @jobs_per_tick = jobs_per_tick
    @job_dur = job_dur

    @upstreams = {}
    upstreams.each do |u|
      @upstreams[u.id] = u
    end

    rr_nodes = {}
    upstreams.each do |u|
      rr_nodes[u.id] = 1000
    end
    @rr = RRBalancer.new(rr_nodes)
  end

  def on_tick
    @jobs_per_tick.times do
      u = least_utilized

      range = @job_dur.last - @job_dur.first
      dur = range * rand + @job_dur.first
      on_completion = Proc.new { |util| update_score(u, util) }

      u.work_on(Job.new(dur.to_i, on_completion))
    end
  end

  def least_utilized
    rr_find
    # actual_least_utilized
  end

  def actual_least_utilized
    min_u = nil
    min_util = 9999999
    @upstreams.values.each do |u|
      if u.utilization < min_util
        min_u = u
        min_util = u.utilization
      end
    end
    return min_u
  end

  def rr_find
    id = @rr.find
    @upstreams[id]
  end

  def update_score(u, util)
    new_score = 1000 - (100 * util).to_i
    @rr.set(u.id, new_score)
  end
end
