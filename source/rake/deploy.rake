require_relative './deploy_task.rb'

namespace :deploy do
  declare_deploy_task(:bootstrap, "Prepares the cluster for distributed deployment",
                      bootstrap: true,
                      quiet: true)

  declare_deploy_task(:provision, "Deploys everything to every server",
                      dependencies: ['deploy:bootstrap'])

  declare_deploy_task(:configure, "Configures every server",
                      dependencies: ['deploy:bootstrap'])
end

desc "Deploys everything to every server"
task :deploy, [:server, :what] => 'deploy:provision'

desc "Configures every server"
task :configure, [:server, :what] => 'deploy:configure'