require 'pry'
require 'benchmark'
require 'concurrent'

@message_queue = Concurrent::Array.new
10000.times { @message_queue << Class.new }

1.times do
  Benchmark.bmbm do |x|
    x.report("reader")  { 100000.times { @message_queue }  }
  end

  Benchmark.bmbm do |x|
    x.report("dup")  { 100000.times { @message_queue.dup }  }
  end

  Benchmark.bmbm do |x|
    # This is super slow.....
    x.report("internal dup")  { 100.times { @message_queue.map(&:dup) }  }
  end

end


