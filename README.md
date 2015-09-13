# Frisky

* [Homepage](http://github.com/MrJoy/frisky)
* [UPnP Device Architecture Documentation](http://upnp.org/specs/arch/UPnP-arch-DeviceArchitecture-v1.0.pdf)


[<img src="https://travis-ci.org/MrJoy/frisky.png?branch=master" alt="Build Status" />](https://travis-ci.org/MrJoy/frisky) [<img src="https://coveralls.io/repos/MrJoy/frisky/badge.png" alt="Coverage Status" />](https://coveralls.io/r/MrJoy/frisky)

## Description

Ruby's UPnP RubyGem was outdated in Ruby 1.9 when support for Soap4r was
dropped.  This gem intends to fill that void for Ruby >= 1.9 and allow for
SSDP search, discovery, advertisement, the ability to act as a UPnP control
point, as well as provide UPnP devices and services.

This uses [EventMachine](http://github.com/eventmachine/eventmachine), so if
you're not already, getting familiar with its concepts will be helpful here.

### This Fork

This fork updates the [playful](http://github.com/turboladen/playful) gem,
which hasn't seen updates in a while.

Specifically:

1. Brings a few dependencies up to date.
2. Gets rid of unfinished/broken, overly-ambitious functionality.

In short, this fork aims to be a simple, minimal way to run SSDP queries and handle the
results.

### Er, what's UPnP??

"Universal Plug and Play" is a mashup of network protocols that let network
devices identify themselves and discover and use each other's services.
Common implementations of UPnP devices are things like:

* [Media Servers and Clients](http://en.wikipedia.org/wiki/List_of_UPnP_AV_media_servers_and_clients) like...
    * PS3
    * Slingbox
    * Xbox
    * XBMC
    * Plex
    * VLC
    * Twonky
    * Mediatomb
* Home Automation
    * Philips Hue


If you have a device that implements UPnP, you can most likely control it
programmatically with `frisky`.  You can't today, but eventually you'll be
able to build your own devices & services with `frisky` that can be consumed
by other UPnP clients (ex. build a media server with frisky and listen on
your PS3...).

## Features

### Implemented

* SSDP search, discovery.


### Coming

* UPnP Devices & Services (server)


## Examples

Take a look at the `tasks` directory; I've created some working examples using
[Thor](https://github.com/wycats/thor).  You can get a list of these tasks by
doing `thor -T`.

There's also a more involved, in-progress, working example at
http://github.com/turboladen/upnp_cp_on_sinatra that uses the Rack middleware
to build a Sinatra app that allows for controling devices in your network.

### SSDP Searches

An SSDP search simply sends the M-SEARCH out to the multicast group and
listens for responses for a given (or default of 5 seconds) amount of time.
The return from this depends on if you're running it within an EventMachine
reactor or not. If not, it returns is an Array of responses as Hashes, where
keys are the header names, values are the header values.  Take a look at the
SSDP.search docs for more on the options here.

```ruby
require 'frisky/ssdp'

# Search for all devices (do an M-SEARCH with the ST header set to 'ssdp:all')
all_devices = Frisky::SSDP.search                         # this is default
all_devices = Frisky::SSDP.search 'ssdp:all'              # or be explicit
all_devices = Frisky::SSDP.search :all                    # or use short-hand

# Search for root devices (do an M-SEARCH with ST header set to 'upnp:rootdevices')
root_devices = Frisky::SSDP.search 'upnp:rootdevices'
root_devices = Frisky::SSDP.search :root                  # or use short-hand

# Search for a device with a specific UUID
my_device = Frisky::SSDP.search 'uuid:3c202906-992d-3f0f-b94c-90e1902a136d'

# Search for devices of a specific type
my_media_server = Frisky::SSDP.search 'urn:schemas-upnp-org:device:MediaServer:1'

# All of these searches will return something that looks like
# => [
#      {
#         :control => "max-age=1200",
#         :date => "Sun, 23 Sep 2012 20:31:48 GMT",
#         :location => "http://192.168.10.3:5001/description/fetch",
#         :server => "Linux-i386-2.6.38-15-generic-pae, UPnP/1.0, PMS/1.50.0",
#         :st => "upnp:rootdevice",
#         :ext => "",
#         :usn => "uuid:3c202906-992d-3f0f-b94c-90e1902a136d::upnp:rootdevice",
#         :length => "0"
#       }
#     ]
```

If you do the search inside of an EventMachine reactor, as the
Frisky::SSDP::Searcher receives and parses responses, it adds them to the
accessor #discovery_responses, which is an EventMachine::Channel.  This lets
you subscribe to the resposnes and do what you want with them as you receive them.

```ruby
require 'frisky/ssdp'

EM.run do
  searcher = Frisky::SSDP.search 'uuid:3c202906-992d-3f0f-b94c-90e1902a136d'

  # Create a deferrable object that can be notified when the device we want
  # has been found and created.
  device_controller = EventMachine::DefaultDeferrable.new

  # This callback will get called when the device_creator callback is called
  # (which is called after the device has been created).
  device_controller.callback do |device|
    p device.service_list.first.service_type          # "urn:schemas-upnp-org:service:ContentDirectory:1"

    # SOAP actions are converted to Ruby methods--show those
    p device.service_list.first.singleton_methods     # [:GetSystemUpdateID, :Search, :GetSearchCapabilities, :GetSortCapabilities, :Browse]

    # Call a SOAP method defined in the service.  The response is extracted from the
    # XML SOAP response and the value is converted from the UPnP dataType to
    # the related Ruby type.  Reponses are always contained in a Hash, so as
    # to maintain the relation defined in the service.
    p device.service_list.first.GetSystemUpdateID     # { :Id => 1 }
  end

  # Note that you don't have to check for items in the Channel or for when the
  # Channel is empty: EventMachine will pop objects off the Channel as soon as
  # they're put there and stop when there are none left.
  searcher.discovery_responses.pop do |notification|
    # Do stuff here.
  end
end
```

## Requirements

* Rubies (tested)
    * 1.9.3
    * 2.0.0
    * 2.1.0
* Gems
    * eventmachine
    * em-http-request
    * em-synchrony
    * nori
    * log_switch
    * savon



## Install

    $ gem install frisky

## Copyright

Copyright (c) 2015 Jon Frisby
Copyright (c) 2012-2014 Steve Loveless

See LICENSE.md for details.
