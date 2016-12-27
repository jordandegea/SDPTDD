require 'sshkit'
require 'sshkit/sudo'
include SSHKit::DSL

def enabled_services(hostname, args = nil)
  filter = (args[:services] || '').split(';')
  filter = $conf['hosts'][hostname]['services'] if filter.length == 0

  $conf['services'].select { |service|
    $conf['hosts'][hostname]['services'].include? service and filter.include? service
  }.collect { |s| "#{s}.service" }
end

def disabled_services(hostname)
  ($conf['services'] - $conf['hosts'][hostname]['services']).collect { |s| "#{s}.service" }
end

namespace :services do
  desc "Reloads the systemd daemon"
  task :daemon_reload, :server do |task, args|
    on hosts(args) do |host|
      sudo "systemctl", "daemon-reload"
    end
  end

  desc "Enables (or disables) services as defined in the host config file"
  task :enable, [:server, :services] do |task, args|
    on hosts(args) do |host|
      # Get the hostname as defined in the config file
      hostname = host.properties.name

      # Disable all services that should not be enabled

      # First sure the services have been stopped
      begin
        sudo "systemctl", "stop", *disabled_services(hostname)
      rescue => e
        # ignore exceptions, services may be already stopped
      end

      # Then disable them
      begin
        sudo "systemctl", "disable", *disabled_services(hostname)
      rescue => e
        # ignore exceptions, services may be already disabled
      end

      # Enable all services that should be enabled
      sudo "systemctl", "enable", *enabled_services(hostname, args)
    end
  end

  desc "Reloads services according to service assignments in the host config file"
  task :reload, [:server, :services] do |task, args|
    on hosts(args) do |host|
      # Get the hostname as defined in the config file
      hostname = host.properties.name

      # Reload all enabled services
      sudo "systemctl", "reload", *enabled_services(hostname, args)
    end
  end

  desc "Starts services according to service assignments in the host config file"
  task :start, [:server, :services] do |task, args|
    on hosts(args) do |host|
      # Get the hostname as defined in the config file
      hostname = host.properties.name

      # Start all enabled services
      sudo "systemctl", "start", *enabled_services(hostname, args)
    end
  end

  desc "Restarts services according to service assignments in the host config file"
  task :restart, [:server, :services] do |task, args|
    on hosts(args) do |host|
      # Get the hostname as defined in the config file
      hostname = host.properties.name

      # Restart all enabled services
      sudo "systemctl", "restart", *enabled_services(hostname, args)
    end
  end

  desc "Stops services according to service assignments in the host config file"
  task :stop, [:server, :services] do |task, args|
    on hosts(args) do |host|
      # Get the hostname as defined in the config file
      hostname = host.properties.name

      # Stop all enabled services
      begin
        sudo "systemctl", "stop", *enabled_services(hostname, args)
      rescue => e
        warn e
      end
    end
  end

  desc "Kills services according to service assignments in the host config file"
  task :kill, [:server, :services] do |task, args|
    on hosts(args) do |host|
      # Get the hostname as defined in the config file
      hostname = host.properties.name

      # Kill all enabled services
      begin
        sudo "systemctl", "kill", *enabled_services(hostname, args)
      rescue => e
        warn e
      end
    end
  end

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
