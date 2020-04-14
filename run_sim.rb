require_relative 'nodes'
require_relative 'latency_factory'

ENABLE_CLEAR_TERM = true

def draw_table(table, clear: true, notes: [])
  header = []
  values = []

  table.each do |col|
    value_format = col[:type] == :float ? ".2f" : "i"

    header << "%#{col[:width]}s"
    values << "%#{col[:width]}#{value_format}"
  end

  header = header.join(", ")
  values = values.join(", ")

  print "\e[H\e[2J" if ENABLE_CLEAR_TERM && clear
  notes.each { |n| puts n }
  puts format(header, *table.map { |c| c[:title] })
  puts format(values, *table.map { |c| c[:value] })
end

def run_sim(num_workers:, num_lbs:, jobs_per_second_per_lb: 1000, lb_options: {})
  workers = []
  num_workers.times do |i|
    workers << Worker.new("upstream_#{i}", 16)
  end

  ms_per_tick = 10
  seconds_per_ms = 1/1000.0
  jobs_per_tick = (ms_per_tick * jobs_per_second_per_lb * seconds_per_ms).to_i

  lbs = []
  num_lbs.times do |i|
    lbs << LB.new(
      "lb_#{i}",
      workers,
      jobs_per_tick,
      LatencyFactory.from_file("latencies.csv"),
      **lb_options
    )
  end

  averages = Hash.new(0)

  duration_s = 30
  ticks = duration_s / 0.01
  ticks.to_i.times do |tick|
    lbs.each { |l| l.tick }
    workers.each { |worker| worker.tick }


    utils = []
    workers.each_with_index do |worker, i|
      # if i < 50
      #   puts "#{worker} util=#{worker.utilization}"
      # end
      utils << worker.utilization
    end

    avg = utils.sum / utils.size.to_f
    sum_squared = utils.map { |u| (u-avg)**2 }.sum
    variance = sum_squared / (utils.size - 1)
    std_dev = Math.sqrt(variance)

    p99_util = utils.dup.sort.drop((utils.count*0.99).to_i).first
    p25_util = utils.dup.sort.drop((utils.count*0.25).to_i).first

    overloaded_threshold = avg + std_dev*3
    overloaded_count = utils.count { |u| u > overloaded_threshold }
    overloaded_percent = overloaded_count / utils.count.to_f

    averages[:avg] += avg.to_f
    averages[:std_dev] += std_dev.to_f
    averages[:overloaded_percent] += overloaded_percent.to_f
    averages[:overloaded_count] += overloaded_count.to_f
    averages[:p99_util] += p99_util.to_f
    averages[:p25_util] += p25_util.to_f
    averages[:count] += 1

    time = tick.to_f/100

    draw_table([
      { title: "time"        , value: time                 , width: 10 , type: :float } ,
      { title: "avg"         , value: avg                  , width: 10 , type: :float } ,
      { title: "std_dev"     , value: std_dev              , width: 10 , type: :float } ,
      { title: "#overloaded" , value: overloaded_count     , width: 15 , type: :int   } ,
      { title: "%overloaded" , value: overloaded_percent   , width: 15 , type: :float } ,
      { title: "p99_util" , value: p99_util , width: 15 , type: :float } ,
      { title: "p25_util" , value: p25_util , width: 15 , type: :float } ,
    ], notes: [
      "Note: overloaded is defined as workers with utilization above <avg + 3 standard deviations> (current_value=#{overloaded_threshold.round(2)})",
      "",
    ])
  end

  puts
  puts "Total Averages"

  table = []
  averages.each do |metric, sum|
    table << { title: metric, value: sum/averages[:count], width: 20 , type: :float }
  end
  draw_table(table, clear: false)
end

begin
  # ENABLE_CLEAR_TERM = false

  run_sim(
    num_workers: 475,
    num_lbs: 16,
    jobs_per_second_per_lb: 1000,
    # healthcheck_period_ticks: 10,
    lb_options: {

      healthcheck_period_ticks: nil,
      # healthcheck_period_ticks: 10,

      # lb_algorithm: :rr,
      lb_algorithm: :ewma_util,
      # lb_algorithm: :ewma_latency,

      perfect_balancing: false,
    }
  )
rescue Interrupt
end
