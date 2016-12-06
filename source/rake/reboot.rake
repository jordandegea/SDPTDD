require 'sshkit'
require 'sshkit/sudo'
include SSHKit::DSL

desc "Reboots the servers"
task :reboot, :server do |task, args|
  on hosts(args) do |host|
    begin
      sudo 'reboot'
    rescue IOError
      # success
    end
  end
end
