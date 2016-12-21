require 'pathname'
require 'sshkit'
require 'sshkit/sudo'
include SSHKit::DSL

# Transfers files from the local host to all the hosts defined in the environment, from the source folders config
# to the working directory for this deployment task.
def file_transfer_bootstrap(args, source_folders_param, working_directory)
  previous = SSHKit.config.output_verbosity
  SSHKit.config.output_verbosity = Logger::INFO

  on hosts(args) do |host|
    # Create the working directory
    host_transfer(host, source_folders_param, working_directory)
  end

  SSHKit.config.output_verbosity = previous
end

# An utility methods that tranfers the files from the source folders to a single host, in the working directory for the
# current deploy task.
def host_transfer(host, source_folders_param, working_directory)
  execute :mkdir, '-p', working_directory

  # Host config node
  host_conf = $conf['hosts'][host.properties.name]

  # Source folders for file deployment
  source_folders = $conf[source_folders_param].dup

  # Add host-specific source folders
  source_folders.concat(host_conf[source_folders_param]) if host_conf[source_folders_param]

  # Push source folders to the working directory
  source_folders.each do |source_folder|
    folder = Pathname.new(File.expand_path(File.join('..', source_folder), $config_source))

    Dir.glob(File.join(folder, '**', '*')).each do |file|
      next if Dir.exist? file

      destination_file = File.join(working_directory, Pathname.new(file).relative_path_from(folder))
      destination_dir = File.dirname(destination_file)

      # Ensure the destination directory is created
      execute :mkdir, '-p', destination_dir unless destination_dir == working_directory

      # Upload the file
      upload! file, destination_file
    end
  end
end

# Transfers files from the local host to all the hosts defined in the environment, from the source folders config
# to the working directory for this deployment task.
#
# This method assumes that the bootstrap step has been performed, allowing SSH access from any host to any other host.
# It uses that assumption to upload all the files to one host, and then pull the uploaded files from all other hosts.
# This strategy minimizes the required upstream bandwidth.
def file_transfer_tree(args, source_folders_param, working_directory)
  previous = SSHKit.config.output_verbosity
  SSHKit.config.output_verbosity = Logger::INFO

  # The list of hosts on which files have not been deployed yet
  pending_hosts = hosts(args).dup

  # Pick one host that will be our starting point
  root_host = pending_hosts.sample
  pending_hosts.delete root_host

  # Upload all the files to this host
  on root_host do |host|
    host_transfer(host, source_folders_param, working_directory)
  end

  # Then, from all other hosts, use SFTP to pull from the root host
  on pending_hosts do |host|
    execute "/bin/bash", "-c", "echo 'get -r #{working_directory}' | sftp #{root_host.properties.name}"
  end

  SSHKit.config.output_verbosity = previous
end

# Performs argument substitution on the input string
def substitute_args!(provisioning_args)
  if provisioning_args =~ /\$hostspec/
    hostspec = $hosts.map do |hostname, host|
      "-H #{hostname}@#{host.hostname}"
    end.join(' ')

    provisioning_args.gsub!(/\$hostspec/, hostspec)
  end

  if provisioning_args =~ /\$hoststring/
    provisioning_args.gsub!(/\$hoststring/, "'#{$hosts.keys.join(' ')}'")
  end
end

def declare_provision_like_task(
  task_name,
  task_desc,
  shared_args_param,
  source_folders_param,
  param_name,
  opts = {})

  # Name of the working directory for the deploy procedure
  working_directory_name = task_name.id2name

  desc task_desc
  task task_name, [:server, :what] do |task, args|
    shared_args = $conf[shared_args_param] || ''

    # Use "FORCE_PROVISION=yes vagrant provision" to re-run provisioning scripts
    # and reinstall everything
    if ENV['FORCE_PROVISION'] == 'yes'
      shared_args += ' -f'
    end

    if opts[:bootstrap]
      file_transfer_bootstrap(args, source_folders_param, working_directory_name)
    else
      file_transfer_tree(args, source_folders_param, working_directory_name)
    end

    on hosts(args) do |host|
      # Host config node
      host_conf = $conf['hosts'][host.properties.name]

      # Change to the working directory
      within working_directory_name do
        steps = (host_conf[param_name]['before'] || []).dup
        steps.concat($conf[param_name] || [])
        steps.concat(host_conf[param_name]['after'] || [])

        steps.each do |p|
          # Provisioning script name and args
          provisioning_name, provisioning_args = [p.keys, p.values].flatten

          # Filter provisioners
          allowed_provisioners = (args[:what] || '').split(';')
          if allowed_provisioners.length == 0 or allowed_provisioners.include? provisioning_name
            script_name = "./#{param_name}_#{provisioning_name}.sh"

            # Specific variables
            substitute_args!(provisioning_args)

            # Get the full path to the current working directory
            cwd = capture(:pwd)

            # Make the script executable
            execute :chmod, '+x', script_name

            # Ensure sudo is in the right path and execute the provisioning script
            sudo "bash -c \"cd #{cwd} && #{script_name} #{shared_args} #{provisioning_args}\""
          end
        end
      end

      # Remove the working directory
      execute :rm, '-rf', working_directory_name
    end
  end
end
