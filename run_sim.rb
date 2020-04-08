require_relative 'nodes'

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
  puts "time=#{tick.to_f/100} avg=#{avg.round(2)}, var=#{(utils.max - utils.min).round(2)}"
  sleep 0.01
end
