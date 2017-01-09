require 'cucumber'
require 'cucumber/rake/task'

# Create cucumber tasks

# List of environments whose scenarios shouldn't be run
skip_envs = Config::ENVIRONMENTS.keys - [$env]

# Opts for all features
base_opts = "--format pretty --tags #{skip_envs.map { |e| '~@' + e.id2name }.join(',')}"

# Default task, run all features
Cucumber::Rake::Task.new(:features) do |task|
  task.cucumber_opts = "features #{base_opts}"
end

namespace :features do
  # Create tasks for each feature
  Dir.glob('features/**.feature').each do |feature|
    # Extract task name from file name
    feature_name = File.basename(feature, '.feature')

    # Declare task
    Cucumber::Rake::Task.new(feature_name.to_sym,
                             "Run Cucumber feature #{File.basename(feature, '.feature')}") do |task|
      task.cucumber_opts = "#{feature} #{base_opts}"
    end
  end
end
