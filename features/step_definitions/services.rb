def systemctl_status(service)
  capture("sudo", "systemctl", "status", "#{service}.service", raise_on_non_zero_exit: false)
end

Given(/^the "([^"]*)" service is running$/) do |service|
  on chosts do
    unless systemctl_status(service) =~ /active \(running\)/
      sudo "systemctl", "start", "#{service}.service"
    end
  end
end

Given(/^the "([^"]*)" service is not running$/) do |service|
  on chosts do
    if systemctl_status(service) =~ /active \(running\)/
      sudo "systemctl", "stop", "#{service}.service"
    end
  end
end

Then(/^the "([^"]*)" service should be running$/) do |service|
  on chosts do
    expect(systemctl_status(service))
      .to match(/active \(running\)/)
  end
end

Then(/^the "([^"]*)" service should not be running$/) do |service|
  on chosts do
    expect(systemctl_status(service))
      .not_to match(/active \(running\)/)
  end
end

Then(/^the "([^"]*)" service should be running on the (\d+)(?:st|nd|rd|th) host$/) do |service, host|
  on chosts(host) do
    expect(systemctl_status(service))
      .to match(/active \(running\)/)
  end
end

Then(/^the "([^"]*)" service should not be running on the (\d+)(?:st|nd|rd|th) host$/) do |service, host|
  on chosts(host) do
    expect(systemctl_status(service))
      .not_to match(/active \(running\)/)
  end
end

Then(/^there should be (\d+) instances? of the "([^"]*)" service running$/) do |instances, service|
  count = 0
  mtx = Mutex.new
  on chosts do
    if systemctl_status(service) =~ /active \(running\)/
      mtx.synchronize do
        count = count + 1
      end
    end
  end
  expect(count).to eq(instances.to_i)
end
