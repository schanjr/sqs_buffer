# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sqs_buffer/version'

Gem::Specification.new do |spec|
  spec.name          = "sqs_buffer"
  spec.version       = SqsBuffer::VERSION
  spec.authors       = ["John Thomas"]
  spec.email         = ["thomas07@vt.edu"]

  spec.summary       = %q{Buffer SQS messages to process more than 10 events}
  spec.description   = %q{SQS only allows you to pull and delete 10 events
at a time. This gem is greedy and will buffer events so you can process
more than 10 at at time.}
  spec.homepage      = "https://github.com/thomas07vt/sqs_buffer.git"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "aws-sdk", "~> 3"
  spec.add_dependency "concurrent-ruby", "~> 1.0"

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'dotenv'
  spec.add_development_dependency 'pry'
end

