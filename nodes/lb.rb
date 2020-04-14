require_relative '../roundrobin'
require_relative '../ewma'

class LB < Node
  MS_PER_TICK = 10

  def initialize(id, workers, jobs_per_tick, latency_generator,
    healthcheck_period_ticks: nil,
    lb_algorithm: :rr,
    perfect_balancing: false
  )
    super(id)
    @jobs_per_tick = jobs_per_tick
    @latency_generator = latency_generator
    @healthcheck_period_ticks = healthcheck_period_ticks
    @lb_algorithm = lb_algorithm
    @perfect_balancing = perfect_balancing

    @workers = {}
    workers.each do |worker|
      @workers[worker.id] = worker
    end

    rr_nodes = {}
    workers.each do |worker|
      rr_nodes[worker.id] = 1
    end
    @rr = RRBalancer.new(rr_nodes)

    ewma_peers = @workers.keys
    @ewma = EWMABalancer.new(ewma_peers, now: ->{@tick})
  end

  def on_tick
    perform_healthchecks

    @jobs_per_tick.times do
      worker = least_utilized

      lat_ms = @latency_generator.next
      job_dur_ticks = lat_ms / MS_PER_TICK

      response_handler = proc { |response| update_score(worker, response) }

      worker.start_job(Job.new(job_dur_ticks, response_handler))
    end
  end

  def least_utilized
    if @perfect_balancing
      return currently_least_utilized
    end

    case @lb_algorithm
    when :rr
      rr_find
    when :ewma_util
      ewma_find
    when :ewma_latency
      ewma_find
    else
      raise "LB Not recognized"
    end
  end

  def update_score(worker, response)
    case @lb_algorithm
    when :rr
      util = response[:utilization]
      rr_score_update(worker, util)
    when :ewma_util
      util = response[:utilization]
      ewma_score_update(worker, util)
    when :ewma_latency
      latency = response[:latency]
      ewma_score_update(worker, latency)
    else
      raise "LB Not recognized"
    end
  end

  def perform_healthchecks
    return unless @healthcheck_period_ticks

    @healthchecks ||= Hash.new(0)
    @workers.each do |_, worker|
      min_jitter = 0
      max_jitter = @healthcheck_period_ticks
      jitter = min_jitter + ((max_jitter - min_jitter) * rand)
      if (@tick - @healthchecks[worker.id] + jitter) > @healthcheck_period_ticks
        update_score(worker, {
          utilization: worker.utilization,
          latency: 200
        })
        @healthchecks[worker.id] = @tick
      end
    end
  end

  def current_least_utilized
    min_worker = nil
    min_util = 9999999
    @workers.values.each do |worker|
      if worker.utilization < min_util
        min_worker = worker
        min_util = worker.utilization
      end
    end
    return min_worker
  end

  def ewma_find
    id = @ewma.find
    @workers[id]
  end

  def rr_find
    id = @rr.find
    @workers[id]
  end

  def ewma_score_update(worker, score)
    @ewma.update_score(worker.id, score)
  end

  def rr_score_update(worker, score)
    score = [1.0, score].min
    new_weight = 100 - (100 * score).to_i
    new_weight = [0, new_weight].max
    new_weight = new_weight+1
    @rr.set(worker.id, new_weight)
  end
end
