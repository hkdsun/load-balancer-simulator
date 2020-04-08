class LatencyGenerator
  def initialize(profile)
    @profile = profile
  end

  def next
    min, max = choose_range(rand)
    min + ((max - min) * rand) # uniform distribution withiin range
  end

  def choose_range(seed)
    fits_range = dist.keys.first
    dist.keys.each do |range|
      if seed <= range
        fits_range = range
      end
    end
    dist[fits_range].map(&:to_f)
  end

  def dist
    @dist ||= {
      0.5    => [@profile[:min], @profile[:p50]],
      0.4   => [@profile[:p50], @profile[:p75]],
      0.1    => [@profile[:p75], @profile[:p90]],
      0.05   => [@profile[:p90], @profile[:p95]],
      0.01   => [@profile[:p95], @profile[:p99]],
      0.009  => [@profile[:p99], @profile[:p999]],
      0.0009 => [@profile[:p999], @profile[:p9999]],
    }
  end
end

class LatencyReader
  def initialize(filename, min_latency = 20)
    @filename = filename
    @min_latency = min_latency
  end

  def next
    lat = enum.next
    if lat < @min_latency
      return self.next
    end
    lat
  rescue StopIteration
    @enum = latencies.shuffle.to_enum
    retry
  end

  def enum
    @enum ||= latencies.shuffle.to_enum
  end

  def latencies
    @latencies ||= read_latencies_from_file
  end

  def read_latencies_from_file
    f = File.open(@filename)
    f.readlines.map(&:to_i)
  ensure
    f.close
  end
end

class LatencyFactory
  DEFAULT_PROFILE = {
    min: 60      ,
    p50: 80      ,
    p75: 150     ,
    p90: 480     ,
    p95: 900     ,
    p99: 2500    ,
    p999: 8000   ,
    p9999: 20000 ,
  }

  def self.from_profile(dist=DEFAULT_PROFILE)
    LatencyGenerator.new(dist)
  end

  def self.from_file(file="latencies.csv")
    LatencyReader.new(file)
  end
end

def test_factory
  require 'pp'

  # lat = LatencyFactory.from_profile
  lat = LatencyFactory.from_file

  decisions = []
  500000.times do
    decisions << lat.next
  end

  sorted = decisions.sort

  stats = {
    avg: sorted.sum / sorted.size.to_f,
    p50: sorted.take((sorted.size * 0.5).to_i).last,
    p75: sorted.take((sorted.size * 0.75).to_i).last,
    p90: sorted.take((sorted.size * 0.9).to_i).last,
    p95: sorted.take((sorted.size * 0.95).to_i + 1).last,
    p99: sorted.take((sorted.size * 0.99).to_i).last,
    p999: sorted.take((sorted.size * 0.999).to_i).last,
    p9999: sorted.take((sorted.size * 0.9999).to_i).last,
  }

  # pp sorted
  pp stats
end
