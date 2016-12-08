require 'sshkit'
require 'sshkit/sudo'
include SSHKit::DSL

def enabled_services(hostname)
  $conf['hosts'][hostname]['services']
end

def disabled_services(hostname)
  $conf['services'] - $conf['hosts'][hostname]['services']
end

namespace :services do
  desc "Reloads the systemd daemon"
  task :reload, :server do |task, args|
    on hosts(args) do |host|
      sudo "systemctl", "daemon-reload"
    end
  end

  desc "Enables (or disables) services as defined in the host config file"
  task :enable, :server do |task, args|
    on hosts(args) do |host|
      # Get the hostname as defined in the config file
      hostname = host.properties.name

      # Disable all services that should not be enabled
      disabled_services(hostname).each do |service|
        # Make sure the service is stopped
        begin
          sudo "systemctl", "stop", "#{service}.service"
        rescue => e
          # ignore exceptions, services may be already stopped
        end

        begin
          sudo "systemctl", "disable", "#{service}.service"
        rescue => e
          # ignore exceptions, services may be already disabled
        end
      end

      # Enable all services that should be enabled
      enabled_services(hostname).each do |service|
        sudo "systemctl", "enable", "#{service}.service"
      end
    end
  end

  desc "Starts services according to service assignments in the host config file"
  task :start, :server do |task, args|
    on hosts(args) do |host|
      # Get the hostname as defined in the config file
      hostname = host.properties.name

      # Start all enabled services
      enabled_services(hostname).each do |service|
        sudo "systemctl", "start", "#{service}.service"
      end
    end
  end

  desc "Stops services according to service assignments in the host config file"
  task :stop, :server do |task, args|
    on hosts(args) do |host|
      # Get the hostname as defined in the config file
      hostname = host.properties.name

      # Stop all enabled services
      enabled_services(hostname).reverse.each do |service|
        sudo "systemctl", "stop", "#{service}.service"
      end
    end
  end

  desc "Kills services according to service assignments in the host config file"
  task :kill, :server do |task, args|
    on hosts(args) do |host|
      # Get the hostname as defined in the config file
      hostname = host.properties.name

      # Stop all enabled services
      enabled_services(hostname).reverse.each do |service|
        sudo "systemctl", "kill", "#{service}.service"
      end
    end
  end

  desc "Restarts services according to service assignments in the host config file"
  task :restart, :server do |task, args|
    on hosts(args) do |host|
      # Get the hostname as defined in the config file
      hostname = host.properties.name

      # Stop all enabled services
      enabled_services(hostname).reverse.each do |service|
        sudo "systemctl", "restart", "#{service}.service"
      end
    end
  end

  desc "Prints the status of services according to service assignments in the host config file"
  task :status, :server do |task, args|
    on hosts(args) do |host|
      # Get the hostname as defined in the config file
      hostname = host.properties.name

      # Stop all enabled services
      enabled_services(hostname).each do |service|
        info capture("systemctl", "status", "#{service}.service")
      end
    end
  end
end