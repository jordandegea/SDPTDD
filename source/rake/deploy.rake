require_relative './deploy_task.rb'

namespace :deploy do
  declare_deploy_task(:bootstrap, "Prepares the cluster for distributed deployment",
                      bootstrap: true,
                      quiet: true)

  declare_deploy_task(:system, "Installs system software and packages",
                      bootstrap: true)

  declare_deploy_task(:software, "Installs core software",
                      dependencies: %w(deploy:bootstrap),
                      weak_dependencies: %w(deploy:system))

  declare_deploy_task(:settings, "Configures core software",
                      dependencies: %w(deploy:bootstrap),
                      weak_dependencies: %w(deploy:system deploy:software))

  declare_deploy_task(:code, "Installs application code",
                      dependencies: %w(deploy:bootstrap),
                      weak_dependencies: %w(deploy:system deploy:software deploy:settings))

  declare_deploy_task(:configure, "Configures every server",
                      dependencies: %w(deploy:bootstrap))
end

desc "Deploys everything to every server"
task :deploy, [:server, :what] => %w(deploy:system deploy:software deploy:code deploy:settings)

desc "Configures every server"
task :configure, [:server, :what] => 'deploy:configure'