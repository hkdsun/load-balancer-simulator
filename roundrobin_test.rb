require_relative 'roundrobin'

nodes = {}
20.times do |i|
  nodes["node_#{i}"] = i % 2 == 0 ? 1 : 2
end

decision = {}
balancer = RRBalancer.new(nodes)

2000.times do |i|
  id = balancer.find
  decision[id] ||= 0
  decision[id] += 1

  if i == 1000
    balancer.set("node_3", 9999)
  end
end

pp decision
