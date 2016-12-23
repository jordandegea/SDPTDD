require 'yaml'
require 'sshkit'

def warn_fail(msg)
  warn msg
  exit 1
end

# Load build config
$build_source = 'build.yml'
$build_conf = YAML.load_file($build_source)

# Fetch the environment name
environment = ENV['RAKE_ENV'] || 'development'

# Compute the config name from this value
$config_source = if environment == 'production'
  'hosts.yml'
elsif environment == 'development'
  'vagrant/vagrant-hosts.yml'
else
  warn_fail("Unknown RAKE_ENV '#{environment}'. Must be 'development' (vagrant) or 'production'.")
end

# Load hostfile from config_source
$conf = YAML.load_file($config_source)

# Create SSHKit hosts
$hosts = $conf['hosts'].collect do |host, params|
  ssh_host = SSHKit::Host.new(
    hostname: params['ip'],
    user: params['user'],
    ssh_options: {
      keys: [File.expand_path(File.join('..', params['key']), $config_source)]
  })

  ssh_host.properties.name = host
  [host, ssh_host]
end.to_h

# Obtains the list of hosts for the current task run
def hosts(args)
  if args[:server]
    args[:server].split(';').collect { |server| $hosts[server] || warn_fail("#{server} is not a known host") }
  else
    $hosts.values
  end
end

# Load custom tasks from `source/rake`
Dir.glob("source/rake/*.rake").each { |r| import r }
