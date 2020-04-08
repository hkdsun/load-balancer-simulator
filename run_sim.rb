require_relative 'nodes'

def draw_table(table, clear: true)
  header = []
  values = []

  table.each do |col|
    value_format = col[:type] == :float ? ".2f" : "i"

    header << "%#{col[:width]}s"
    values << "%#{col[:width]}#{value_format}"
  end

  header = header.join(", ")
  values = values.join(", ")

  print "\e[H\e[2J" if clear
  puts format(header, *table.map { |c| c[:title] })
  puts format(values, *table.map { |c| c[:value] })
end

# 700 upstreams per lb
upstreams = []
700.times do |i|
  upstreams << Worker.new("upstream_#{i}", 20)
end

# 10 ms per tick
jobs_per_tick = 7 # 700 jobs per second per lb
job_dur = (20..80) # uniform: 200ms - 20000ms

# 17 lbs per cluster
lbs = []
17.times do |i|
  lbs << LB.new("lb_#{i}", upstreams, jobs_per_tick, job_dur)
end

samples = {
  avg:                0,
  std_dev:            0,
  overloaded_count:   0,
  overloaded_percent: 0,
  count:              0,
}

duration_s = 30
ticks = duration_s / 0.01
ticks.to_i.times do |tick|
  lbs.each { |l| l.tick }
  upstreams.each { |u| u.tick }


  utils = []
  upstreams.each do |u|
    utils << u.utilization
  end

  avg = utils.sum / utils.size.to_f
  sum_squared = utils.map { |u| (u-avg)**2 }.sum
  variance = sum_squared / (utils.size - 1)
  std_dev = Math.sqrt(variance)

  overloaded_thresholdd = avg + std_dev*3
  overloaded_count = utils.count { |u| u > overloaded_thresholdd }
  overloaded_percent = overloaded_count / utils.count.to_f

  samples[:avg] += avg.to_f
  samples[:std_dev] += std_dev.to_f
  samples[:overloaded_percent] += overloaded_percent.to_f
  samples[:overloaded_count] += overloaded_count.to_f
  samples[:count] += 1

  time = tick.to_f/100

  draw_table([
    { title: "time"        , value: time               , width: 10 , type: :float } ,
    { title: "avg"         , value: avg                , width: 10 , type: :float } ,
    { title: "std_dev"     , value: std_dev            , width: 10 , type: :float } ,
    { title: "#overloaded" , value: overloaded_count   , width: 15 , type: :int   } ,
    { title: "%overloaded" , value: overloaded_percent , width: 15 , type: :float } ,
  ])
end

puts
puts "Total Averages"
draw_table([
  { title: "avg"                , value: samples[:avg]/samples[:count]                , width: 20 , type: :float } ,
  { title: "std_dev"            , value: samples[:std_dev]/samples[:count]            , width: 20 , type: :float } ,
  { title: "overloaded_count"   , value: samples[:overloaded_count]/samples[:count]   , width: 20 , type: :float } ,
  { title: "overloaded_percent" , value: samples[:overloaded_percent]/samples[:count] , width: 20 , type: :float } ,
  { title: "count"              , value: samples[:count]/samples[:count]              , width: 20 , type: :float } ,
], clear: false)
