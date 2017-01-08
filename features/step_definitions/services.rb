Given(/^the "([^"]*)" service is not running$/) do |service|
  on hosts do
    try_sudo "systemctl", "stop", "#{service}.service"
  end
end

Then(/^the "([^"]*)" service should be running$/) do |service|
  on hosts do
    expect(capture("sudo", "systemctl", "status", "#{service}.service"))
      .to match(/active \(running\)/)
  end
end

Then(/^the "([^"]*)" service should not be running$/) do |service|
  on hosts do
    expect(capture("sudo", "systemctl", "status", "#{service}.service"))
      .not_to match(/active \(running\)/)
  end
end

Then(/^the "([^"]*)" service should be running on the (\d+)(?:st|nd|rd|th) host$/) do |service, host|
  on hosts(host) do
    expect(capture("sudo", "systemctl", "status", "#{service}.service"))
      .to match(/active \(running\)/)
  end
end

Then(/^the "([^"]*)" service should not be running on the (\d+)(?:st|nd|rd|th) host$/) do |service, host|
  on hosts(host) do
    expect(capture("sudo", "systemctl", "status", "#{service}.service"))
      .not_to match(/active \(running\)/)
  end
end
