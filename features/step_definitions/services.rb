Given(/^the "([^"]*)" service is not running$/) do |service|
  rake_run("services:stop[,#{service}]")
end

Then(/^the "([^"]*)" service should be running$/) do |service|
  expect(rake_capture("services:status[,#{service}]")[0])
    .to match(/active \(running\)/)
end

Then(/^the "([^"]*)" service should not be running$/) do |service|
  expect(rake_capture("services:status[,#{service}]")[0])
    .not_to match(/active \(running\)/)
end

Then(/^the "([^"]*)" service should be running on the (\d+)(?:st|nd|rd|th) host$/) do |service, host|
  expect(rake_capture("services:status[#{nth_host(host)},#{service}]")[0])
    .to match(/active \(running\)/)
end

Then(/^the "([^"]*)" service should not be running on the (\d+)(?:st|nd|rd|th) host$/) do |service, host|
  expect(rake_capture("services:status[#{nth_host(host)},#{service}]")[0])
    .not_to match(/active \(running\)/)
end
