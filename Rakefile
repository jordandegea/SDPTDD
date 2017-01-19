require_relative 'source/rake/config.rb'
require_relative 'source/rake/formatter.rb'

# Load build config
$build_source = 'build.yml'
$build_conf = YAML.load_file($build_source)

# Load host config
Config.load_config(File.expand_path('..', __FILE__))

# Helper method to obtains the list of hosts for the current run
def hosts(args = nil)
  if args and args[:server]
    args[:server].split(';').collect { |server| $hosts[server] ||
                                       Config.warn_fail("#{server} is not a known host") }
  else
    $hosts.values
  end
end

# Load custom tasks from `source/rake`
Dir.glob("source/rake/*.rake").each { |r| import r }

# The main task
desc "Deploys, formats name nodes and starts the cluster"
if $env == :development
  task :up => %w(vagrant:reup deploy run:format_hdfs services:start)
else
  task :up => %w(deploy run:format_hdfs services:start)
end
