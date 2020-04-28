def nextTime(rate)
  -Math.log(1.0 - rand) / rate;
end

1000.times do
  puts nextTime(1000)
end
