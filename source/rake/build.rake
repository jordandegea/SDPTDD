require 'tempfile'

build_groups = Hash.new { |hash, k| hash[k] = Array.new }

($build_conf['build_outputs'] || {}).each do |output_file, spec|
  # Build dependencies array for the current build output
  dependencies = []
  (spec['dependencies'] || []).each do |dep_spec|
    dependencies.concat(Dir.glob(dep_spec))
  end

  # Declare the build task
  file output_file => dependencies do
    Tempfile.open do |tmpfile|
      # Write the build script contents
      File.write(tmpfile.path, spec['build_script'])

      # Make sure it is executable
      tmpfile.chmod(0755)

      # Execute it
      if RUBY_PLATFORM =~ /mswin|mingw|bccwin|wince|emx/
        # On Windows, delegate to mingw bash
        sh 'bash', tmpfile.path
      else
        # Note that Cygwin is a linux
        sh tmpfile.path
      end
    end
  end

  # Register the build task in the corresponding build groups
  (spec['groups'] || []).each do |build_group|
    build_groups[build_group] << output_file
  end
end

namespace :build do
  # Create the "build:all" task
  desc "build all applications"
  task :all => $build_conf['build_outputs'].keys

  # Create build tasks for groups
  build_groups.each do |group_name, dependencies|
    desc "build applications from the #{group_name} group"
    task group_name.to_sym => dependencies
  end
end

# The "build" task
desc "build all applications"
task :build => 'build:all'
