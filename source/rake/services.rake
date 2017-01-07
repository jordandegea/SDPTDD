require 'sshkit'
require 'sshkit/sudo'
include SSHKit::DSL

def enabled_services(hostname, args = nil)
  filter = (args[:services] || '').split(';')

  if filter.length == 0
    $conf['services'].collect { |s| "#{s}.service" }
  else
    $conf['services'].select { |service|
      filter.include? service 
    }.collect { |s| "#{s}.service" }
  end
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
      info capture("systemctl", "status", *enabled_services(hostname, args))
    end
  end
end
