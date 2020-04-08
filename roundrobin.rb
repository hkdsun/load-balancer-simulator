require 'pp'

class RRBalancer
  def initialize(nodes)
    newnodes = nodes.dup
    only_key, gcd, max_weight = get_gcd(newnodes)
    last_id = get_random_node_id(nodes)

    @nodes = newnodes
    @only_key = only_key
    @max_weight = max_weight
    @gcd = gcd
    @cw = max_weight
    @last_id = last_id
  end

  def set(id, new_weight=0)
    old_weight = @nodes[id]

    return if old_weight == new_weight

    if old_weight < new_weight
      return _incr(id, new_weight - old_weight)
    end
    return _decr(id, old_weight - new_weight)
  end

  def find
    only_key = @only_key
    if only_key then
      return only_key
    end

    nodes = @nodes
    last_id, cw = [@last_id, @cw]

    while true do
      while true do
        last_id, weight = next_in_hash(nodes, last_id)
        if not last_id
          break
        end

        if weight >= cw
          @cw = cw
          @last_id = last_id
          return last_id
        end
      end

      cw = cw - @gcd
      if cw <= 0
        cw = @max_weight
      end
    end
  end

  def next_in_hash(hash, starting_key=nil)
    keys = hash.keys

    if keys.size == 0
      return nil
    end

    if starting_key == nil
      starting_key = keys.first
    end

    index = hash.keys.index(starting_key)
    unless index
      return nil
    end

    if index+1 == keys.size
      return nil
    end

    key = keys[index+1]
    return [key, hash[key]]
  end

  private

  def _incr(id, weight=1)
    @nodes[id] = (@nodes[id] || 0) + weight
    @only_key, @gcd, @max_weight = get_gcd(@nodes)
  end

  def _decr(id, weight=1)
    old_weight = @nodes[id]
    return unless old_weight

    if old_weight <= weight
      return _delete(id)
    end

    @nodes[id] = old_weight - weight

    @only_key, @gcd, @max_weight = get_gcd(@nodes)
    if @cw > @max_weight
      @cw = @max_weight
    end
  end

  def _delete(id)
    @nodes[id] = nil
    @only_key, @gcd, @max_weight = get_gcd(@nodes)

    if id == @last_id
      @last_id = nil
    end

    if @cw > @max_weight
      @cw = @max_weight
    end
  end

  def get_gcd(nodes)
    first_id, max_weight = nodes.first
    unless first_id
      raise "empty nodes"
    end

    only_key = first_id
    gcd = max_weight
    nodes.each do |id, weight|
      only_key = nil
      gcd = _gcd(gcd, weight)
      max_weight = weight > max_weight ? weight : max_weight
    end

    return [only_key, gcd, max_weight]
  end

  def _gcd(a, b)
    if b == 0
      return a
    end

    return _gcd(b, a % b)
  end

  def get_random_node_id(nodes)
    nodes.keys.sample
  end
end
