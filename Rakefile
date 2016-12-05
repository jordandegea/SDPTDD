require 'yaml'
require 'sshkit'

# Load hostfile
$conf = YAML.load_file(File.expand_path('../hosts.yml', __FILE__))

# Create SSHKit hosts
$hosts = $conf['hosts'].collect do |host, params|
  ssh_host = SSHKit::Host.new(
    hostname: params['ip'],
    user: params['user'],
    ssh_options: {
      keys: [File.expand_path(File.join('..', params['key']), __FILE__)]
  })

  ssh_host.properties.name = host
  [host, ssh_host]
end.to_h

# Load custom tasks from `source/rake`
Dir.glob("source/rake/*.rake").each { |r| import r }
