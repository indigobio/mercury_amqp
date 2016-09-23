# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'mercury_amqp'
  spec.version       = '0.6.1'
  spec.authors       = ['Peter Winton']
  spec.email         = ['wintonpc@gmail.com']
  spec.summary       = 'AMQP-backed messaging layer'
  spec.description   = 'Abstracts common patterns used with AMQP'
  spec.homepage      = 'https://github.com/wintonpc/mercury_amqp'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'yard', '~> 0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'json_spec', '~> 1'
  spec.add_development_dependency 'evented-spec', '~> 0.9'
  spec.add_development_dependency 'rspec_junit_formatter', '~> 0'

  spec.add_runtime_dependency 'oj', '~> 2.12'
  spec.add_runtime_dependency 'amqp', '~> 1.5'
  spec.add_runtime_dependency 'bunny', '~> 2.1'
  spec.add_runtime_dependency 'binding_of_caller', '~> 0.7'
  spec.add_runtime_dependency 'logatron', '~> 0'
  spec.add_runtime_dependency 'activesupport', '> 4.0', '< 6.0'
end
