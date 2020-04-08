require_relative '../roundrobin'

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
    # rr_find
    actual_least_utilized
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
