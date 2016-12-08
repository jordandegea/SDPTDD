require 'pathname'
require 'sshkit'
require 'sshkit/sudo'
include SSHKit::DSL

# Runs a configuring entry
def configure(shared_args, p, args)
  # configuring script name and args
  configuring_name, configuring_args = [p.keys, p.values].flatten

  # Filter configureers
  allowed_configureers = (args[:what] || '').split(';')
  if allowed_configureers.length > 0
    return unless allowed_configureers.include? configuring_name
  end

  script_name = "./configure_#{configuring_name}.sh"

  # Specific variables
  if configuring_args =~ /\$hostspec/
    hostspec = $hosts.map do |hostname, host|
      "-H #{hostname}@#{host.hostname}"
    end.join(' ')

    configuring_args.gsub!(/\$hostspec/, hostspec)
  end

  # Get the full path to the current working directory
  cwd = capture(:pwd)

  # Make the script executable
  execute :chmod, '+x', script_name

  # Ensure sudo is in the right path and execute the configuring script
  sudo "bash -c \"cd #{cwd} && #{script_name} #{shared_args} #{configuring_args}\""
end

desc "Configures the server according to the hostfile"
task :configure, [:server, :what] do |task, args|
  shared_args = $conf['shared_configure_args'] || ''

  on hosts(args) do |host|
    # Create the configure directory
    execute :mkdir, '-p', 'configure'

    # Host config node
    host_conf = $conf['hosts'][host.properties.name]

    # Source folders for file configuration
    configure_folders = $conf['configure_folders'].dup

    # Add host-specific source folders
    configure_folders.concat(host_conf['configure_folders']) if host_conf['configure_folders']

    previous = SSHKit.config.output_verbosity
    SSHKit.config.output_verbosity = Logger::INFO

    # Push source folders to the configure directory
    configure_folders.each do |configure_folder|
      folder = Pathname.new(File.expand_path(File.join('..', configure_folder), $config_source))

      Dir.glob(File.join(folder, '**', '*')).each do |file|
        next if Dir.exist? file

        destination_file = File.join('configure', Pathname.new(file).relative_path_from(folder))
        destination_dir = File.dirname(destination_file)

        # Ensure the destination directory is created
        execute :mkdir, '-p', destination_dir unless destination_dir == 'configure'

        # Upload the file
        upload! file, destination_file
      end
    end

    SSHKit.config.output_verbosity = previous

    # Change to the configure directory
    within 'configure' do
      # Run 'before' configuring scripts
      (host_conf['configuring']['before'] || []).each do |p|
        configure(shared_args, p, args)
      end

      # Run 'shared' configuring scripts
      $conf['configuring'].each do |p|
        configure(shared_args, p, args)
      end

      # Run 'after' configuring scripts
      (host_conf['configuring']['after'] || []).each do |p|
        configure(shared_args, p, args)
      end
    end

    # Remove the configure directory
    execute :rm, '-rf', 'configure'
  end
end
