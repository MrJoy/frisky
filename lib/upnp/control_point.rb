require 'open-uri'
require 'nori'
require_relative 'ssdp'

begin
  require 'nokogiri'
rescue LoadError
  # Fail quietly
end

# Allows for controlling a UPnP device as defined in the UPnP spec for control
# points.
#
# It uses +Nori+ for parsing the description XML files, which will use +Nokogiri+
# if you have it installed.
module UPnP
  class ControlPoint
    attr_reader :devices
    attr_reader :services

    def initialize(ip='0.0.0.0', port=0)
      @ip = ip
      @port = port
      @devices = []
      @services = []
      Nori.parser = :nokogiri if defined? ::Nokogiri
    end

    # @param [String] search_type
    # @param [Fixnum] max_wait_time The MX value to use for searching.
    # @param [Fixnum] ttl
    # @return [Hash]
    # @todo This should be removed and just allow direct access to SSDP.
    def find_devices(search_type, max_wait_time, ttl=4)
      @devices = UPnP::SSDP.search(search_type, max_wait_time, ttl)

      @devices.each do |device|
        device[:description] = get_description(device[:location])
      end
    end

    def find_services
      if @devices.empty?
        @services = []
        return
      end

      @devices.each do |device|
        device[:description]["root"]["device"]["serviceList"]["service"].each do |service|
          scpd_url = build_scpd_url(device[:description]["root"]["URLBase"], service["SCPDURL"])
          service[:description] = get_description(scpd_url)
          @services << service
        end
      end
    end
    private

    def get_description(location)
      Nori.parse(open(location).read)
    end

    def build_scpd_url(url_base, scpdurl)
      if url_base.end_with?('/') && scpdurl.start_with?('/')
        scpdurl.sub!('/', '')
      end

      url_base + scpdurl
    end

  end
end
