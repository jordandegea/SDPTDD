require 'pathname'
require 'sshkit'
require 'sshkit/sudo'
include SSHKit::DSL

# Runs a provisioning entry
def provision(shared_args, p)
  # Provisioning script name and args
  provisioning_name, provisioning_args = [p.keys, p.values].flatten
  script_name = "./provisioning_#{provisioning_name}.sh"

  # Specific variables
  if provisioning_args =~ /\$hostspec/
    hostspec = $hosts.map do |hostname, host|
      "-H #{hostname}@#{host.hostname}"
    end.join(' ')

    provisioning_args.gsub!(/\$hostspec/, hostspec)
  end

  # Get the full path to the current working directory
  cwd = capture(:pwd)

  # Make the script executable
  execute :chmod, '+x', script_name

  # Ensure sudo is in the right path and execute the provisioning script
  sudo "bash -c \"cd #{cwd} && #{script_name} #{shared_args} #{provisioning_args}\""
end

desc "Deploys everything to every server"
task :deploy, :server do |task, args|
  shared_args = $conf['shared_args'] || ''

  # Use "FORCE_PROVISION=yes vagrant provision" to re-run provisioning scripts
  # and reinstall everything
  if ENV['FORCE_PROVISION'] == 'yes'
    shared_args += ' -f'
  end

  on hosts(args) do |host|
    # Create the deploy directory
    execute :mkdir, '-p', 'deploy'

    # Push source folders to the deploy directory
    $conf['source_folders'].each do |source_folder|
      folder = Pathname.new(source_folder)

      Dir.glob(File.join(folder, '**')).each do |file|
        destination_file = File.join('deploy', Pathname.new(file).relative_path_from(folder))
        destination_dir = File.dirname(destination_file)

        # Ensure the destination directory is created
        execute :mkdir, '-p', destination_dir unless destination_dir == 'deploy'

        # Upload the file
        upload! file, destination_file
      end
    end

    # Change to the deploy directory
    within 'deploy' do
      # Run 'before' provisioning scripts
      ($conf['hosts'][host.properties.name]['provisioning']['before'] || []).each do |p|
        provision(shared_args, p)
      end

      # Run 'shared' provisioning scripts
      $conf['provisioning'].each do |p|
        provision(shared_args, p)
      end

      # Run 'after' provisioning scripts
      ($conf['hosts'][host.properties.name]['provisioning']['after'] || []).each do |p|
        provision(shared_args, p)
      end
    end

    # Remove the deploy directory
    execute :rm, '-rf', 'deploy'
  end
end