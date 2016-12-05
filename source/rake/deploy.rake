require 'pathname'
require 'sshkit'
require 'sshkit/sudo'
include SSHKit::DSL

desc "Deploys everything to every server"
task :deploy do |task, args|
  shared_args = ''

  # Use "FORCE_PROVISION=yes vagrant provision" to re-run provisioning scripts
  # and reinstall everything
  if ENV['FORCE_PROVISION'] == 'yes'
    shared_args = '-f'
  end

  on $hosts.values do |host|
    # Create the deploy directory
    execute :mkdir, '-p', 'deploy'

    # Push source folders to the deploy directory
    $conf['source_folders'].each do |source_folder|
      folder = Pathname.new(source_folder)

      Dir.glob(File.join(folder, '**')).each do |file|
        unless file == '.'
          upload! file,
            File.join('deploy', Pathname.new(file).relative_path_from(folder))
        end
      end
    end

    # Change to the deploy directory
    within 'deploy' do
      $conf['provisioning'].each do |p|
        # Provisioning script name and args
        provisioning_name, provisioning_args = [p.keys, p.values].flatten
        script_name = "./provisioning_#{provisioning_name}.sh"

        # Get the full path to the current working directory
        cwd = capture(:pwd)

        # Make the script executable
        execute :chmod, '+x', script_name

        # Ensure sudo is in the right path and execute the provisioning script
        sudo "bash -c \"cd #{cwd} && #{script_name} #{shared_args} #{provisioning_args}\""
      end
    end

    # Remove the deploy directory
    execute :rm, '-rf', 'deploy'
  end
end