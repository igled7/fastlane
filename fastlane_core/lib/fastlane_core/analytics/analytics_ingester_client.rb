require 'faraday'
require 'openssl'
require 'json'

require_relative '../helper'

module FastlaneCore
  class AnalyticsIngesterClient
    def initialize(ga_tracking)
      @ga_tracking = ga_tracking
    end

    def post_events(events)
      # If our users want to opt out of usage metrics, don't post the events.
      # Learn more at https://docs.fastlane.tools/#metrics
    unless Helper.test? or FastlaneCore::Env.truthy?("FASTLANE_OPT_OUT_USAGE")
        Thread.new do
          send_request(events)
        end
      end
      return true
    end

    def send_request(events, retries: 2)
      post_request(events)
    rescue
      retries -= 1
      retry if retries >= 0
    end

    def post_request(events)
      if ENV['METRICS_DEBUG']
        write_json(events.to_json)
      end
      url = "https://www.google-analytics.com"

      connection = Faraday.new(url) do |conn|
        conn.request(:url_encoded)
        conn.adapter(Faraday.default_adapter)
        if ENV['METRICS_DEBUG']
          conn.proxy = "https://127.0.0.1:8888"
          conn.ssl[:verify_mode] = OpenSSL::SSL::VERIFY_NONE
        end
      end
      connection.headers[:user_agent] = 'Fastlane'
      events.each do |event|
        connection.post("/collect", {
          v: "1",                                            # API Version
          tid: @ga_tracking,                                 # Tracking ID / Property ID
          cid: event[:category],                             # Client ID
          t: "event",                                        # Event hit type
          ec: event[:category],                              # Event category
          ea: event[:action],                                # Event action
          el: event[:label] || "na",                         # Event label
          ev: event[:value] || "0"                           # Event value
        })
      end
    end

    # This method is only for debugging purposes
    def write_json(body)
      File.write("#{ENV['HOME']}/Desktop/mock_analytics-#{Time.now.to_i}.json", body)
    end
  end
end
