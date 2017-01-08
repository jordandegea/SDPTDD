require 'yaml'
require 'sshkit'

module Config
  # Definition of all the possible rake environments
  ENVIRONMENTS = { development: 'vagrant/vagrant-hosts.yml',
                   production:  'hosts.yml' }

  # Print a warning message and exit the processus with non-zero
  def self.warn_fail(msg)
    warn msg
    exit 1
  end

  # Injects the config into global variables:
  # * $env: current environment
  # * $ref_path: path for all relative references in the config
  # * $conf: root node of the config tree
  # * $hosts: defined hosts as SSHKit::Host instances
  def self.load_config(ref_path, env = nil)
    env ||= ENV['RAKE_ENV'] || 'development'
    $env = env = env.downcase.to_sym

    # Find out the config file location
    config_source = ENVIRONMENTS[env]

    # Exit if we are using an unknown environment
    unless config_source
      warn_fail("Unknown RAKE_ENV '#{env.id2name}'. Must be " +
                "#{ENVIRONMENTS.keys.map { |k| k.id2name }.join(' or ')}.")
    end

    # Load the config file
    $conf = YAML.load_file(config_source)

    # Inject ref_path
    $ref_path = ref_path

    # Create SSHKit hosts
    $hosts = $conf['hosts'].collect do |host, params|
      ssh_host = SSHKit::Host.new(
        hostname: params['ip'],
        user: params['user'],
        ssh_options: {
          keys: [File.expand_path(params['key'], $ref_path)]
      })

      ssh_host.properties.name = host
      [host, ssh_host]
    end.to_h
  end
end