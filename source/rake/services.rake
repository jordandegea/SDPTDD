require 'sshkit'
require 'sshkit/sudo'
include SSHKit::DSL

def enabled_services(hostname, args = nil)
  from_args = (args[:services] || '').split(';')
  from_args = $conf['services'] if from_args.length == 0
  from_args.collect { |s| "#{s}.service" }
end

namespace :services do
  desc "Reloads the systemd daemon"
  task :daemon_reload, :server do |task, args|
    on hosts(args) do |host|
      sudo "systemctl", "daemon-reload"
    end
  end

  def systemctl_task(args)
    task_name, task_desc = args

    desc task_desc
    task task_name, [:server, :services] do |task, args|
      on hosts(args) do |host|
        # Get the hostname as defined in the config file
        hostname = host.properties.name

        # Execute the action on all the enabled services
        begin
          sudo "systemctl", task_name.id2name, *enabled_services(hostname, args)
        rescue => e
          error e
        end
      end
    end
  end

  {
    enable: "Enables (or disables) services as defined in the host config file",
    reload: "Reloads services according to service assignments in the host config file",
    start: "Starts services according to service assignments in the host config file",
    restart: "Restarts services according to service assignments in the host config file",
    stop: "Stops services according to service assignments in the host config file",
    kill: "Kills services according to service assignments in the host config file"
  }.each(&method(:systemctl_task))

  desc "Prints the status of services according to service assignments in the host config file"
  task :status, [:server, :services] do |task, args|
    on hosts(args) do |host|
      # Get the hostname as defined in the config file
      hostname = host.properties.name

      # Status all enabled services
      info capture("systemctl", "status", *enabled_services(hostname, args), raise_on_non_zero_exit: false)
    end
  end

  desc "Prints the status according to service_watcher"
  task :watcher do
    on hosts.sample(1) do |host|
      # Get the hostname as defined in the config file
      hostname = host.properties.name

      # Status all enabled services
      info "sudo service_watcher status output: \n" +
        capture("sudo", "service_watcher", "status")
    end
  end
end
