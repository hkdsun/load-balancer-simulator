require_relative '../roundrobin'

class LB < Node
  MS_PER_TICK = 10

  def initialize(id, upstreams, jobs_per_tick, latency_generator, healthcheck_period_ticks: nil)
    super(id)
    @jobs_per_tick = jobs_per_tick
    @latency_generator = latency_generator
    @healthcheck_period_ticks = healthcheck_period_ticks

    @upstreams = {}
    upstreams.each do |u|
      @upstreams[u.id] = u
    end

    rr_nodes = {}
    upstreams.each do |u|
      rr_nodes[u.id] = 1
    end
    @rr = RRBalancer.new(rr_nodes)
  end

  def on_tick
    perform_healthchecks

    @jobs_per_tick.times do
      u = least_utilized

      lat_ms = @latency_generator.next
      job_dur_ticks = lat_ms / MS_PER_TICK

      on_completion = Proc.new { |util| update_score(u, util) }

      u.work_on(Job.new(job_dur_ticks, on_completion))
    end
  end

  def least_utilized
    rr_find
    # actual_least_utilized
  end

  def perform_healthchecks
    return unless @healthcheck_period_ticks

    @healthchecks ||= Hash.new(0)
    @upstreams.each do |_, u|
      min_jitter = 0
      max_jitter = @healthcheck_period_ticks
      jitter = min_jitter + ((max_jitter - min_jitter) * rand)
      if (@tick - @healthchecks[u.id] + jitter) > @healthcheck_period_ticks
        update_score(u, u.utilization)
        @healthchecks[u.id] = @tick
      end
    end
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
    util = [1.0, util].min
    new_weight = 100 - (100 * util).to_i
    new_weight = [0, new_weight].max
    new_weight = new_weight+1
    # puts new_weight
    @rr.set(u.id, new_weight)
  end
end
