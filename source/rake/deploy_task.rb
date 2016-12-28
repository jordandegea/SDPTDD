require 'pathname'
require 'sshkit'
require 'sshkit/sudo'
require 'open3'
require 'erb'
include SSHKit::DSL

def with_log_level(level)
  previous = SSHKit.config.output_verbosity
  begin
    SSHKit.config.output_verbosity = level
    yield
  ensure
    SSHKit.config.output_verbosity = previous
  end
end

# Transfers files from the local host to all the hosts defined in the environment, from the source folders config
# to the working directory for this deployment task.
def file_transfer_bootstrap(args, source_folders_param, working_directory, deploy_root)
  on hosts(args) do |host|
    # Create the working directory
    host_transfer(host, source_folders_param, working_directory, deploy_root)
  end
end

# An utility methods that tranfers the files from the source folders to a single host, in the working directory for the
# current deploy task.
def host_transfer(host, source_folders_param, working_directory, deploy_root)
  # Remove the directory first
  begin
    sudo :rm, '-rf', working_directory
  rescue => e
    # ignore errors removing directory
  end
  execute :mkdir, '-p', working_directory

  # Host config node
  host_conf = $conf['hosts'][host.properties.name]

  # Source folders for file deployment
  source_folders = deploy_root[source_folders_param].dup

  # Add host-specific source folders
  source_folders.concat(host_conf[source_folders_param]) if host_conf[source_folders_param]

  # Push source folders to the working directory
  begin
    Open3.popen2e("sftp", "-o", "StrictHostKeyChecking=no", "-i", host.ssh_options[:keys][0], "#{host.user}@#{host.hostname}") do |stdin, stdout, wait_thr|
      source_folders.each do |source_folder|
        folder = File.expand_path(File.join('..', source_folder), $config_source)

        info "[#{host.properties.name}] uploading #{folder}"

        stdin.puts "lcd '#{folder}'"
        stdin.puts "cd #{working_directory}"
        stdin.puts "put -r ."
      end
      stdin.close

      stdout.each do |line|
        debug "[#{host.properties.name}] #{line}"
      end

      unless wait_thr.value.success?
        fail "aborting because an error occurred transferring files"
      end
    end
  rescue => e
    warn "[#{host.properties.name}] failed to transfer using SFTP, trying using Net::SCP, this will be slower"

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
end

# Transfers files from the local host to all the hosts defined in the environment, from the source folders config
# to the working directory for this deployment task.
#
# This method assumes that the bootstrap step has been performed, allowing SSH access from any host to any other host.
# It uses that assumption to upload all the files to one host, and then pull the uploaded files from all other hosts.
# This strategy minimizes the required upstream bandwidth.
def file_transfer_tree(args, source_folders_param, working_directory, deploy_root)
  # The list of hosts on which files have not been deployed yet
  pending_hosts = hosts(args).dup

  # Pick one host that will be our starting point
  root_host = pending_hosts.first
  pending_hosts.delete root_host

  # Upload all the files to this host
  on root_host do |host|
    host_transfer(host, source_folders_param, working_directory, deploy_root)
  end

  # Then, from all other hosts, use SFTP to pull from the root host
  on pending_hosts do |host|
    execute "printf 'ls -al\\nget -r #{working_directory}' | sftp #{root_host.properties.name}"
  end
end

# An environment class for variable template evaluation
class TemplateNamespace
  def initialize(hash)
    hash.each do |k, v|
      singleton_class.send(:define_method, k) { v }
    end
  end

  def get_binding
    binding
  end
end

# Evaluates the variables for the current deploy environment
def get_variables(deploy_root)
  # ERB environment
  env = TemplateNamespace.new(hosts: $hosts.collect do |host, ssh_host|
    OpenStruct.new(
      name: host,
      address: ssh_host.hostname
    )
  end)

  deploy_root['variables'].collect do |name, template|
    [ name, ERB.new(template).result(env.get_binding) ]
  end.to_h
end

# Performs argument substitution on the input string
def substitute_args!(provisioning_args, variables)
  variables.each do |varname, value|
    provisioning_args.gsub!("$#{varname}", value)
  end
end

def declare_deploy_task(
  task_name,
  task_desc,
  opts = {})

  # Name of the working directory for the deploy procedure
  working_directory_name = task_name.id2name

  # Name of the main parameter in config files
  param_name = task_name.id2name

  # Name of the shared args parameter
  shared_args_param = "shared_args"

  # Name of the source folders parameter
  source_folders_param = "#{task_name.id2name}_folders"

  # Root key for deploy tasks
  deploy_root = $conf['deploy'] || {}

  desc task_desc
  task task_name, [:server, :what] => (opts[:dependencies] || []) do |task, args|
    shared_args = deploy_root[shared_args_param] || ''

    # Use "FORCE_PROVISION=yes vagrant provision" to re-run provisioning scripts
    # and reinstall everything
    if ENV['FORCE_PROVISION'] == 'yes'
      shared_args += ' -f'
    end

    with_log_level(if opts[:extra_quiet] then Logger::WARN else Logger::INFO end) do
      if opts[:bootstrap]
        file_transfer_bootstrap(args, source_folders_param, working_directory_name, deploy_root)
      else
        file_transfer_tree(args, source_folders_param, working_directory_name, deploy_root)
      end
    end

    warned_user = false
    mtx = Mutex.new

    with_log_level(if opts[:extra_quiet] then Logger::WARN else (if opts[:quiet] then Logger::INFO else Logger::DEBUG end) end) do
      # Compute variables substitution
      variables = get_variables(deploy_root)

      on hosts(args) do |host|
        mtx.synchronize do
          if opts[:weak_dependencies]
            unless warned_user
              needed_tasks = opts[:weak_dependencies].select { |task| not Rake::Task[task].already_invoked }.to_a
              if needed_tasks.length > 0
                warn "make sure you already ran the following deployment tasks: #{needed_tasks.join(', ')}"
              end
              warned_user = true
            end
          end
        end

        # Host config node
        host_conf = $conf['hosts'][host.properties.name]

        # Change to the working directory
        within working_directory_name do
          host_conf_node = host_conf[param_name] || {}
          steps = (host_conf_node['before'] || []).dup
          steps.concat(deploy_root[param_name] || [])
          steps.concat(host_conf_node['after'] || [])

          steps.each do |p|
            # Provisioning script name and args
            provisioning_name, provisioning_args = [p.keys, p.values].flatten
            provisioning_args ||= ''

            # Filter provisioners
            allowed_provisioners = (args[:what] || '').split(';')
            if allowed_provisioners.length == 0 or allowed_provisioners.include? provisioning_name
              script_name = "./#{param_name}_#{provisioning_name}.sh"

              # Specific variables
              substitute_args!(provisioning_args, variables)

              # Get the full path to the current working directory
              cwd = capture(:pwd)

              # Make the script executable
              execute :chmod, '+x', script_name

              begin
                # Ensure sudo is in the right path and execute the provisioning script
                sudo "bash -c \"cd #{cwd} && #{script_name} #{shared_args} #{provisioning_args}\"".strip
              rescue SSHKit::Command::Failed => e
                error "[#{host.properties.name}] failed task #{param_name}:#{provisioning_name}: #{e.message}"
                warn "[#{host.properties.name}] aborting provisioning of host due to errors"
                break
              end
            end
          end
        end

        # Remove the working directory (using sudo)
        sudo :rm, '-rf', working_directory_name
      end
    end
  end
end
