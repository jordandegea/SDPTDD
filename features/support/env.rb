require 'open3'
require 'sshkit'
require 'sshkit/sudo'
require 'rspec/expectations'

# Loading rake to execute without reloading ruby env each time
require 'rake'
old_argv = ARGV
self.class.send(:remove_const, 'ARGV')
self.class.const_set('ARGV', [])
Rake.application.init
Rake.application.load_rakefile
self.class.send(:remove_const, 'ARGV')
self.class.const_set('ARGV', old_argv)

# SSHKit is used within steps
include SSHKit::DSL
SSHKit.config.output_verbosity = Logger::WARN

# Enable the use of RSpec expectations while in SSHKit
class SSHKit::Backend::Abstract
  include RSpec::Matchers
end

# Load config
require_relative '../../source/rake/config.rb'

# Load host config
Config.load_config(File.expand_path('../../..', __FILE__))

# Some helper methods
def capture_stdout
  s = StringIO.new
  oldstdout = $stdout
  $stdout = s
  yield
  s.string
ensure
  $stdout = oldstdout
end

def rake_run(task_name)
  @rake_status ||= {}

  # Store the status and output of the rake task
  output = nil
  status = false

  begin
    # Parse task name
    name, args = Rake.application.parse_task_string(task_name)

    # Execute the task, capturing its output
    output = capture_stdout do
      Rake.application[name].reenable
      Rake.application[name].invoke(*args)
    end

    status = true
  rescue => e
    warn e
  end

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

def chosts(name = nil)
  if name.nil?
    $hosts.values
  else
    $hosts.select { |k, v| k == name }.collect { |k, v| v }
  end
end
