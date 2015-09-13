require 'pp'
require File.expand_path(File.dirname(__FILE__)+ '/../lib/frisky/ssdp')
require File.expand_path(File.dirname(__FILE__)+ '/../lib/frisky/logger')

module Frisky
  class Ssdp < Thor
    #---------------------------------------------------------------------------
    # search
    #---------------------------------------------------------------------------
    desc 'search TARGET', 'Searches for devices of type TARGET'
    method_option :response_wait_time, default: 5
    method_option :ttl, default: 4
    method_option :do_broadcast_search, type: :boolean
    method_option :log, type: :boolean
    def search(target='upnp:rootdevice')
      ::Frisky.logging_enabled = options[:log]
      time_before = Time.now
      results     = ::Frisky::SSDP.search(target, options.dup)
                    .map { |r| r[:location] }
                    .sort
      unique      = results.uniq
      time_after  = Time.now

      puts <<-RESULTS
size: #{results.size}
locations: #{results.join("\n           ")}
unique size: #{unique.size}
unique locations: #{unique.join("\n                  ")}
search duration: #{time_after - time_before}
      RESULTS

      results
    end
  end
end
