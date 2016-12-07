require 'yaml'
require 'sshkit'

# Load hostfile
config_source = ENV['RAKE_HOSTS'] || 'hosts.yml'
config_file = File.expand_path(File.join('..', config_source), __FILE__)
$conf = YAML.load_file(config_file)

# Create SSHKit hosts
$hosts = $conf['hosts'].collect do |host, params|
  ssh_host = SSHKit::Host.new(
    hostname: params['ip'],
    user: params['user'],
    ssh_options: {
      keys: [File.expand_path(File.join('..', params['key']), config_file)]
  })

  ssh_host.properties.name = host
  [host, ssh_host]
end.to_h

# Obtains the list of hosts for the current task run
def hosts(args)
  if args[:server]
    args[:server].split(';').collect { |server| $hosts[server] || raise("#{server} is not a known host") }
  else
    $hosts.values
  end
end

# Load custom tasks from `source/rake`
Dir.glob("source/rake/*.rake").each { |r| import r }
