require_relative 'ewma'

nodes = []
20.times do |i|
  nodes << "node_#{i}"
end

tick = 0
balancer = EWMABalancer.new(nodes, now: ->{tick})

decision = {}
8000.times do |i|
  if i % 3 == 0
    tick += 1
  end

  id = balancer.find
  decision[id] ||= 0
  decision[id] += 1

  # if id == "node_10"
  #   balancer.update_score(id, 10)
  # else
  #   balancer.update_score(id, 1)
  # end
end

pp decision
