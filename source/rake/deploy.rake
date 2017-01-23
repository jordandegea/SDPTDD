require_relative './deploy_task.rb'

namespace :deploy do
  declare_deploy_task(:bootstrap, "Prepares the cluster for distributed deployment",
                      bootstrap: true,
                      extra_quiet: true)

  declare_deploy_task(:system, "Installs system software and packages",
                      dependencies: %w(deploy:bootstrap),
                      quiet: true)

  declare_deploy_task(:software, "Installs core software",
                      weak_dependencies: %w(deploy:bootstrap deploy:system))

  declare_deploy_task(:settings, "Configures core software",
                      weak_dependencies: %w(deploy:bootstrap deploy:system deploy:software))

  # Note the dependency on the build task here
  declare_deploy_task(:code, "Installs application code",
                      dependencies: %w(build),
                      weak_dependencies: %w(deploy:bootstrap deploy:system deploy:software deploy:settings))

  declare_deploy_task(:configure, "Configures every server",
                      weak_dependencies: %w(deploy:bootstrap services:start))

  desc "Performs a full deploy"
  task :full, [:server, :what] => %w(deploy:system deploy:software deploy:settings deploy:code)

  desc "Performs a full user deploy"
  task :soft, [:server, :what] => %w(deploy:software deploy:code deploy:settings)

  desc "Performs a user deploy"
  task :user, [:server, :what] => %w(deploy:code deploy:settings)

  desc "Performs a fast deploy"
  task :fast, [:server, :what] => %w(deploy:settings)
end

desc "Deploys everything to every server"
task :deploy, [:server, :what] => 'deploy:full'

desc "Configures every server"
task :configure, [:server, :what] => 'deploy:configure'