require "open3"

require_relative '../../source/rake/config.rb'

# Load host config
Config.load_config(File.expand_path('../../..', __FILE__))

# Some helper methods
def rake_capture(task_name)
  Open3.capture2e("rake", task_name)
end

def rake_run(task_name)
  @rake_status ||= {}

  # Store the status and output of the rake task
  output, status = rake_capture(task_name)
  @rake_status[task_name] = {
    output: output,
    status: status
  }

  # Store the name of the last task executed, for the "the task should *"
  @rake_status[:last_task] = task_name
end

def nth_host(n)
  n = n.to_i unless n.is_a? Integer
  $hosts.keys.sort[n]
end
