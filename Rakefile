require 'yaml'
require 'sshkit'
include SSHKit::DSL

# Load hostfile
conf = YAML.load_file(File.expand_path('../hosts.yml', __FILE__))

# Create SSHKit hosts
hosts = conf['hosts'].collect do |host, params|
    [host, SSHKit::Host.new(hostname: params['ip'],
                     user: params['user'],
                     ssh_options: {
                         keys: [File.expand_path(File.join('..', params['key']), __FILE__)]
                     })]
end.to_h

desc "Opens an SSH shell to the given host"
task :ssh do |task, args|
  # shift everything until ssh so we can rake --trace --smth ssh
  while ARGV.first =~ /^(-|ssh$)/
    break if ARGV.shift == 'ssh'
  end

  # Find the host
  host = hosts[ARGV.first]
  raise "#{ARGV.first} not found" unless host

  # Run SSH command
  sh "ssh", "-i", host.ssh_options[:keys].first, "#{host.user}@#{host.hostname}"

  # https://stackoverflow.com/questions/3586997/how-to-pass-multiple-parameters-to-rake-task
  #
  # By default, rake considers each 'argument' to be the name of an actual task.
  # It will try to invoke each one as a task.  By dynamically defining a dummy
  # task for every argument, we can prevent an exception from being thrown
  # when rake inevitably doesn't find a defined task with that name.
  ARGV.each do |arg|
    task arg.to_sym do
    end
  end
end

desc "Deploys everything to every server"
task :deploy do |task, args|
    shared_args = ''

    # Use "FORCE_PROVISION=yes vagrant provision" to re-run provisioning scripts
    # and reinstall everything
    if ENV['FORCE_PROVISION'] == 'yes'
        shared_args = '-f'
    end

    on hosts.values do |host|
        # Create the deploy directory
        execute :mkdir, '-p', 'deploy'

        # Push source folders to the deploy directory
        conf['source_folders'].each do |source_folder|
            Dir.glob(File.join(source_folder, '**')).each do |file|
                unless file == '.'
                    upload! file, File.join('deploy', File.basename(file)), recursive: true
                end
            end
        end

        # Change to the deploy directory
        within 'deploy' do
            conf['provisioning'].each do |p|
                provisioning_name, provisioning_args = [p.keys, p.values].flatten
                script_name = "./provisioning_#{provisioning_name}.sh"
                execute :chmod, '+x', script_name
                execute "sudo bash -c \"cd deploy && #{script_name} #{shared_args} #{provisioning_args}\""
            end
        end

        # Remove the deploy directory
        execute :rm, '-rf', 'deploy'
    end
end