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
    # puts @tick
  end

  def print
    visual = "@" * [jobs, 42].min
    puts "#{visual}[ #{@id} ]"
  end
end

class Job
  attr_accessor :remaining_dur

  def initialize(duration_ticks, on_completion)
    @remaining_dur = duration_ticks
    @on_completion = on_completion
  end

  def on_tick(util)
    @remaining_dur -= 1
    if @remaining_dur <= 0
      # puts "completed job"
      @on_completion.call(util)
      true
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
    res = []
    in_progress.each_with_index do |job, i|
      if i+1 > @capacity
        res << job
      else
        # puts "working on job #{job}, remaining_dur=#{job.remaining_dur}"
        job_completed = job.on_tick(utilization)
        unless job_completed
          res << job
        end
      end
    end
    @in_progress = res
  end

  def work_on(job)
    in_progress << job
  end

  def in_progress
    @in_progress ||= []
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
      rr_nodes[u.id] = 1
    end
    @rr = RRBalancer.new(rr_nodes)
  end

  def on_tick
    @jobs_per_tick.times do
      u = least_utilized

      range = @job_dur.last - @job_dur.first
      dur = range * rand + @job_dur.first
      on_completion = Proc.new { |util| update_score(u, util) }

      u.work_on(Job.new(dur, on_completion))
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
    @rr.set(u.id, util)
  end
end

# 700 upstreams per lb
upstreams = []
700.times do |i|
  upstreams << Worker.new("upstream_#{i}", 20)
end

# 10 ms per tick
jobs_per_tick = 7 # 700 jobs per second per lb
job_dur = (20..80) # uniform: 200ms - 800ms

# 17 lbs per cluster
lbs = []
17.times do |i|
  lbs << LB.new("lb_#{i}", upstreams, jobs_per_tick, job_dur)
end

duration_s = 30
ticks = duration_s / 0.01

ticks.to_i.times do |tick|
  lbs.each { |l| l.tick }
  upstreams.each { |u| u.tick }


  utils = []
  print "\e[H\e[2J"
  upstreams.each_with_index do |u, i|
    util = u.utilization
    if i < 50 || u.utilization > 2
      puts "#{u}: util=#{util}"
    end
    utils << util
  end
  avg = utils.sum / utils.size.to_f
  puts "tick=#{tick} avg=#{avg.round(2)}, var=#{(utils.max - utils.min).round(2)}"
  sleep 0.01
end
