require_relative './deploy_task.rb'

namespace :deploy do
  declare_deploy_task(:provision,
                      "Deploys everything to every server",
                      "source_folders",
                      bootstrap: true)

  declare_deploy_task(:configure,
                      "Configures every server",
                      "configure_folders",
                      bootstrap: true)
end

desc "Deploys everything to every server"
task :deploy => 'deploy:provision'

desc "Configures every server"
task :configure => 'deploy:configure'
