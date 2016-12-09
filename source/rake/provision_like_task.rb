def declare_provision_like_task(task_name, task_desc, shared_args_param_name,
  working_directory_name, source_folders_param_name, main_param_name,
  script_template_name)
  desc task_desc
  task task_name, [:server, :what] do |task, args|
    shared_args = $conf[shared_args_param_name] || ''

    # Use "FORCE_PROVISION=yes vagrant provision" to re-run provisioning scripts
    # and reinstall everything
    if ENV['FORCE_PROVISION'] == 'yes'
      shared_args += ' -f'
    end

    previous = SSHKit.config.output_verbosity
    SSHKit.config.output_verbosity = Logger::INFO

    on hosts(args) do |host|
      # Create the working directory
      execute :mkdir, '-p', working_directory_name

      # Host config node
      host_conf = $conf['hosts'][host.properties.name]

      # Source folders for file deployment
      source_folders = $conf[source_folders_param_name].dup

      # Add host-specific source folders
      source_folders.concat(host_conf[source_folders_param_name]) if host_conf[source_folders_param_name]

      # Push source folders to the working directory
      source_folders.each do |source_folder|
        folder = Pathname.new(File.expand_path(File.join('..', source_folder), $config_source))

        Dir.glob(File.join(folder, '**', '*')).each do |file|
          next if Dir.exist? file

          destination_file = File.join(working_directory_name, Pathname.new(file).relative_path_from(folder))
          destination_dir = File.dirname(destination_file)

          # Ensure the destination directory is created
          execute :mkdir, '-p', destination_dir unless destination_dir == working_directory_name

          # Upload the file
          upload! file, destination_file
        end
      end
    end

    SSHKit.config.output_verbosity = previous

    on hosts(args) do |host|
      # Host config node
      host_conf = $conf['hosts'][host.properties.name]

      # Change to the working directory
      within working_directory_name do
        steps = (host_conf[main_param_name]['before'] || []).dup
        steps.concat($conf[main_param_name] || [])
        steps.concat(host_conf[main_param_name]['after'] || [])

        steps.each do |p|
          # Provisioning script name and args
          provisioning_name, provisioning_args = [p.keys, p.values].flatten

          # Filter provisioners
          allowed_provisioners = (args[:what] || '').split(';')
          if allowed_provisioners.length == 0 or allowed_provisioners.include? provisioning_name
            script_name = "./#{script_template_name}_#{provisioning_name}.sh"

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
        end
      end

      # Remove the working directory
      execute :rm, '-rf', working_directory_name
    end
  end
end
