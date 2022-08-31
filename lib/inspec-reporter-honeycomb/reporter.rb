
require 'inspec/plugin/v2'
require 'json'
require "securerandom" unless defined?(SecureRandom)

module InspecPlugins::HoneycombReporter
  # Reporter Plugin Class
  class Reporter < Inspec.plugin(2, :reporter)
    def render
      output(report.to_json, false)
    end
    
    def self.run_data_schema_constraints
        '~> 0.0' # Accept any non-breaking change
    end
    
    def report
      report = Inspec::Reporters::Json.new(@config).report
      trace_id = SecureRandom.hex(16)
      root_span_id = SecureRandom.hex(8)
      trace_batch = []
      root_span_data = Hash.new
      root_span_data[:data] = {
        'trace.trace_id' => trace_id,
        'trace.span_id' => root_span_id,
        'service.name' => 'compliance',
        'name' => 'inspec-run',
        'platform.name' => report[:platform][:name],
        'duration' => report[:statistics][:duration]*1000,
        'version' => report[:version],
      }

      trace_batch << root_span_data

      report[:profiles].each do |profile|
        profile_span_id = SecureRandom.hex(8)
        profile[:controls].each do |control|
            control_span_id = SecureRandom.hex(8)
            control[:results].each do |result|
                result_span_id = SecureRandom.hex(8)
                trace_batch << generate_span_data(
                    parent_id: control_span_id,
                    span_id: result_span_id,
                    trace_id: trace_id,
                    data: result,
                    platform: report[:platform][:name],
                    type: 'result',
                    name: result[:code_desc],
                    duration: result[:run_time],
                )
            end
            control.tap { |ct| ct.delete(:results) }
            trace_batch << generate_span_data(
                parent_id: profile_span_id,
                span_id: control_span_id,
                trace_id: trace_id,
                data: control,
                platform: report[:platform][:name],
                type: 'control',
                name: control[:title],
            )
        end
        profile.tap { |pf| pf.delete(:controls) }
        trace_batch << generate_span_data(
            parent_id: root_span_id,
            span_id: profile_span_id,
            trace_id: trace_id,
            data: profile,
            platform: report[:platform][:name],
            type: 'profile',
        )
      end

      

      headers = { "Content-Type" => "application/json" }
      headers["X-Honeycomb-Team"] = ENV['HONEYCOMB_API_KEY']

      uri = URI(ENV['HONEYCOMB_API_URL'])
      req = Net::HTTP::Post.new(uri.path, headers)
      req.body = trace_batch.to_json
      begin
        Inspec::Log.debug "Posting report to Honeycomb: #{uri.path}"
        http = Net::HTTP.new(uri.hostname, uri.port)
        http.use_ssl = uri.scheme == "https"
        if ENV['VERIFY_SSL'] == true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        else
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end

        res = http.request(req)
        if res.is_a?(Net::HTTPSuccess)
          true
        else
          Inspec::Log.error "send_report: POST to #{uri.path} returned: #{res.body}"
          false
        end
      rescue => e
        Inspec::Log.error "send_report: POST to #{uri.path} returned: #{e.message}"
        false
      end
    end

    private

    def generate_span_data(**args)

        time_in_ms = args[:duration] ? args[:duration] * 1000 : 0
        span_data = {
            'trace.trace_id' => args[:trace_id],
            'trace.span_id' => args[:span_id],
            'service.name' => 'compliance',
            'trace.parent_id' => args[:parent_id],
            'platform.name' => args[:platform],
            'type' => args[:type],
            'name' => args[:name],
            'duration' => time_in_ms,
        }

        args[:data].each do |k,v|
            if v.is_a?(Array)
                value = v.join(",")
            else
                value = v
            end
            span_data[k] = value.to_s
        end
        return_data = Hash.new
        return_data[:data] = span_data
        return_data
    end

  end
end