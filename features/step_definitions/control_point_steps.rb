When /^I create my control point$/ do
  @control_point = Frisky::ControlPoint.new(:root)
end

When /^tell it to find all root devices$/ do
  @control_point.start do
    @control_point.stop
  end
end

# TODO: This requires a different control-point object due to differences in
# TODO: the real API vs. the one the tests were written against.
When /^tell it to find all services$/ do
  pending
end

Then /^it gets a list of root devices$/ do
  @control_point.devices.should_not be_empty
end

Then /^it gets a list of services$/ do
  @control_point.services.should_not be_empty
end
