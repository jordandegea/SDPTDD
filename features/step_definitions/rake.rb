When(/^I run the rake task "([^"]*)"$/) do |task_name|
  rake_run(task_name)
end

When(/^I run the rake task "([^"]*)" on the (\d+)(?:st|nd|rd|th) host$/) do |task_name, host_n|
  host_name = nth_host(host_n)

  if task_name =~ /[a-z]\[/
    # the task name contains an argument already
    task_name.gsub! /([a-z]\[)/, "\\1#{host_name}"
  else
    # the task name does not contain an argument
    task_name += "[#{host_name}]"
  end

  rake_run(task_name)
end

Then(/^the task should succeed$/) do
  expect(@rake_status[:last_task]).not_to be_nil
  expect(@rake_status[@rake_status[:last_task]][:status]).to be true
end
