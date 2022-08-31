lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'inspec-reporter-honeycomb'
  spec.version       = '0.1.1'
  spec.authors       = ['Andy Dufour']
  spec.email         = ['andy.k.dufour@gmail.com']
  spec.summary       = 'InSpec Reporter plugin for Honeycomb'
  spec.description   = 'InSpec Reporter plugin to report Otel formatted traces to Honeycomb.'
  spec.homepage      = 'https://github.com/andy-dufour/inspec-reporter-honeycomb'
  spec.license       = 'Apache-2.0'
  spec.require_paths = ['lib']
  spec.files = Dir.glob('{{lib}/**/*,inspec-reporter-honeycomb.gemspec}').reject { |f| File.directory?(f) }

  spec.required_ruby_version = '>= 2.7'
  spec.add_runtime_dependency 'opentelemetry-sdk'
  spec.add_runtime_dependency 'opentelemetry-exporter-otlp'

  spec.add_development_dependency 'inspec'
end
