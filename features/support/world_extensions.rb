module HelperStuff
  def control_point(target = :root)
    @control_point ||= {}
    @control_point[target] ||= Frisky::ControlPoint.new(target)
  end

  def fake_device_collection
    @fake_device_collection ||= FakeUPnPDeviceCollection.instance
  end

  def local_ip
    @local_ip ||= local_ip_and_port.first
  end
end

World(HelperStuff)
