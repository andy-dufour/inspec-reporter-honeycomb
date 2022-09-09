
require 'inspec/plugin/v2'
require 'json'
require 'socket'
require 'securerandom' unless defined?(SecureRandom)

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
      report = Inspec::Reporters::JsonAutomate.new(@config).report
      trace_id = SecureRandom.hex(16)
      root_span_id = SecureRandom.hex(8)
      trace_batch = []
      ip_addresses = []
      Socket.ip_address_list.each do |ipaddr|
        ip_addresses << ipaddr.ip_address unless ipaddr.ip_address == '127.0.0.1'
      end
      root_span_data = Hash.new
      root_span_data[:data] = {
        'trace.trace_id' => trace_id,
        'trace.span_id' => root_span_id,
        'service.name' => 'compliance',
        'name' => 'inspec-run',
        'platform.name' => report[:platform][:name],
        'platform.release' => report[:platform][:release],
        'duration' => report[:statistics][:duration]*1000,
        'version' => report[:version],
        'hostname' => Socket.gethostname,
        'arch' => ::RbConfig::CONFIG['arch'],
        'os' => ::RbConfig::CONFIG['host_os'],
        'ip_addresses' => ip_addresses,
      }

      trace_batch << root_span_data

      report[:profiles].each do |profile|
        profile_span_id = SecureRandom.hex(8)
        profile_duration = 0.0
        profile_statuses = []
        profile_name = profile[:name]
        profile_title = profile[:title]
        profile_version = profile[:version]
        profile_attributes = profile[:attributes]
        profile[:controls].each do |control|
          control_span_id = SecureRandom.hex(8)
          control_duration = 0.0
          control_statuses = []
          control_name = control[:name]
          control_id = control[:id]
          control_desc = control[:desc]
          control_impact = control[:impact]
          control[:results].each do |result|
            result_span_id = SecureRandom.hex(8)
            control_duration += result[:run_time]
            control_statuses << result[:status]
            trace_batch << generate_span_data(
              parent_id: control_span_id,
              span_id: result_span_id,
              trace_id: trace_id,
              data: result,
              platform: report[:platform][:name],
              platform_release: report[:platform][:release],
              type: 'result',
              name: result[:code_desc],
              duration: result[:run_time],
              profile_name: profile_name,
              profile_title: profile_title,
              profile_version: profile_version,
              profile_attributes: profile_attributes,
              control_name: control_name,
              control_id: control_id,
              control_desc: control_desc,
              control_impact: control_impact,
            )
          end
          control.tap { |ct| ct.delete(:results) }
          profile_duration += control_duration
          profile_statuses += control_statuses
          control_status = get_status(control_statuses)
          trace_batch << generate_span_data(
            parent_id: profile_span_id,
            span_id: control_span_id,
            trace_id: trace_id,
            data: control,
            status: control_status,
            platform: report[:platform][:name],
            platform_release: report[:platform][:release],
            type: 'control',
            duration: control_duration,
            name: control[:title],
            profile_name: profile_name,
            profile_title: profile_title,
            profile_version: profile_version,
            profile_attributes: profile_attributes,
            control_name: control_name,
            control_id: control_id,
            control_desc: control_desc,
            control_impact: control_impact,
          )
        end
        profile.tap { |pf| pf.delete(:controls); pf.delete(:status) }
        profile_status = get_status(profile_statuses)
        trace_batch << generate_span_data(
          parent_id: root_span_id,
          span_id: profile_span_id,
          trace_id: trace_id,
          data: profile,
          status: profile_status,
          platform: report[:platform][:name],
          platform_release: report[:platform][:release],
          duration: profile_duration,
          type: 'profile',
          profile_name: profile_name,
          profile_title: profile_title,
          profile_version: profile_version,
          profile_attributes: profile_attributes,
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
          Inspec::Log.debug "send_report: Honeycomb POST to #{uri.path} succeeded and returned: #{res.body} "
        else
          Inspec::Log.error "send_report: POST to #{uri.path} returned: #{res.body}"
          false
        end
      rescue => e
        Inspec::Log.error "send_report: POST to #{uri.path} returned: #{e.message}"
        false
      end
      Inspec::Log.debug "Successfully sent report"
    end

    private

    def safe_time(time)
      if time.nil?
        nil
      else
        time.iso8601(fraction_digits = 3)
      end
    end

    def get_status(status_array)
      if status_array.include?('failed')
        'failed'
      elsif status_array.include?('skipped') && !status_array.include?('passed')
        'skipped'
      elsif status_array.empty?
        'skipped'
      else
        'passed'
      end
    end

    def generate_span_data(**args)

        time_in_ms = args[:duration] ? args[:duration] * 1000 : 0
        span_data = {
            'trace.trace_id' => args[:trace_id],
            'trace.span_id' => args[:span_id],
            'service.name' => 'compliance',
            'trace.parent_id' => args[:parent_id],
            'platform.name' => args[:platform],
            'platform.release' => args[:platform_release],
            'status' => args[:status],
            'type' => args[:type],
            'name' => args[:name],
            'duration' => time_in_ms,
            'hostname' => Socket.gethostname,
            'arch' => ::RbConfig::CONFIG['arch'],
            'os' => ::RbConfig::CONFIG['host_os'],
            'ip_addresses' => args[:ip_addresses],
            'profile.name' => args[:profile_name],
            'profile.title' => args[:profile_title],
            'profile.version' => args[:profile_version],
            'profile.attributes' => args[:profile_attributes],
            'control.name' => args[:control_name],
            'control.id' => args[:control_id],
            'control.desc' => args[:control_desc],
            'control.impact' => args[:control_impact],
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