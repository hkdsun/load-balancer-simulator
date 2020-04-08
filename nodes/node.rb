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
  end
end
