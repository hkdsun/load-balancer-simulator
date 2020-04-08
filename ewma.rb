class EWMABalancer
  DEFAULT_DECAY_TIME = 10
  PICK_SET_SIZE = 2

  def initialize(peers, decay_time=DEFAULT_DECAY_TIME, now: ->{ Time.now.to_i })
    @decay_time = decay_time
    @peers = peers
    @now = now
  end

  def shuffle_peers(peers, k)
    k.times do |i|
      rand_index = rand(0...peers.size)
      peers[i], peers[rand_index] = peers[rand_index], peers[i]
    end
  end

  def score(peer)
    get_or_update_ewma(peer, 0, false)
  end

  def pick_and_score(peers, k)
    shuffle_peers(peers, k)

    lowest_score_index = 1
    lowest_score = score(peers[lowest_score_index])

    k.times do |i|
      i += 1
      new_score = score(peers[i])
      if new_score < lowest_score
        lowest_score_index, lowest_score = i, new_score
      end
    end

    return peers[lowest_score_index], lowest_score
  end

  def decay_ewma(ewma, last_touched_at, score, now)
    td = now - last_touched_at
    td = (td > 0) ? td : 0
    weight = Math.exp(-td/@decay_time)

    ewma = ewma * weight + score * (1.0 - weight)
    return ewma
  end

  def store_stats(peer, ewma, now)
    ewma_scores_last_touched_at[peer] = now
    ewma_scores[peer] = ewma
  end

  def get_or_update_ewma(peer, score, update)
    ewma = ewma_scores[peer] || 0

    now = @now.call
    last_touched_at = ewma_scores_last_touched_at[peer] || 0
    ewma = decay_ewma(ewma, last_touched_at, score, now)

    unless update
      return ewma
    end

    store_stats(peer, ewma, now)
    return ewma
  end

  def find
    endpoint, _ewma_score = [@peers[0], -1]

    if @peers.size > 1
      k = (@peers.size < PICK_SET_SIZE) ? @peers.size : PICK_SET_SIZE
      peer_copy = @peers.dup
      endpoint, _ewma_score = pick_and_score(peer_copy, k)
    end

    return endpoint
  end

  def set(peer, score)
    if peer.empty?
      raise "wtf"
    end

    get_or_update_ewma(peer, score, true)
  end

  def ewma_scores
    @ewma_scores ||= {}
  end

  def ewma_scores_last_touched_at
    @ewma_scores_last_touched_at ||= {}
  end
end

nodes = []
20.times do |i|
  nodes << "node_#{i}"
end

tick = 0
balancer = EWMABalancer.new(nodes, now: ->{tick})

decision = {}
2000.times do |i|
  if i % 3 == 0
    tick += 1
  end

  id = balancer.find
  decision[id] ||= 0
  decision[id] += 1

  if id == "node_10"
    balancer.set(id, 10)
  else
    balancer.set(id, 1)
  end
end

pp decision
