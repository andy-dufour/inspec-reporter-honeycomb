require 'inspec/plugin/v2'

module InspecPlugins
  module HoneycombReporter
    class Plugin < Inspec.plugin(2)
      plugin_name :'inspec-reporter-honeycomb'

      reporter :honeycomb do
        require_relative 'reporter.rb'
        InspecPlugins::HoneycombReporter::Reporter
      end
    end
  end
end