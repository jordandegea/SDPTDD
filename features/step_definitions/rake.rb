require "open3"

When(/^I run the rake task "([^"]*)"$/) do |task_name|
  @rake_status ||= {}

  # Store the status and output of the rake task
  output, status = Open3.capture2e("rake", task_name)
  @rake_status[task_name] = {
    output: output,
    status: status
  }

  # Store the name of the last task executed, for the "the task should *"
  @rake_status[:last_task] = task_name
end

Then(/^the task should succeed$/) do
  expect(@rake_status[:last_task]).not_to be_nil
  expect(@rake_status[@rake_status[:last_task]][:status].success?).to be true
end
