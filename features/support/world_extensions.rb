module HelperStuff
  def local_ip
    @local_ip ||= local_ip_and_port.first
  end
end

World(HelperStuff)
