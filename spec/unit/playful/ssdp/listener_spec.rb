require 'spec_helper'
require 'frisky/ssdp/listener'


describe Frisky::SSDP::Listener do
  around(:each) do |example|
    EM.synchrony do
      example.run
      EM.stop
    end
  end

  before do
    allow_any_instance_of(Frisky::SSDP::Listener).to receive(:setup_multicast_socket)
  end

  subject { Frisky::SSDP::Listener.new(1) }

  describe '#receive_data' do
    it 'logs the IP and port from which the request came from' do
      expect(subject).to receive(:peer_info).and_return %w[ip port]
      expect(subject).to receive(:log).
        with("Response from ip:port:\nmessage\n")
      allow(subject).to receive(:parse).and_return({})

      subject.receive_data('message')
    end
  end
end
