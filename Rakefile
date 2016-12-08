require 'yaml'
require 'sshkit'

SSHKit.config.output_verbosity = Logger::DEBUG

# Fetch the environment name
environment = ENV['RAKE_ENV'] || 'development'

# Compute the config name from this value
$config_source = if environment == 'production'
  'hosts.yml'
elsif environment == 'development'
  'source/vagrant/vagrant-hosts.yml'
else
  fail "Unknown RAKE_ENV '#{environment}'. Must be 'development' (vagrant) or 'production'."
end

# Load hostfile from config_source
config_file = File.expand_path(File.join('..', $config_source), __FILE__)
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
