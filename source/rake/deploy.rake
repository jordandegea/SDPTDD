require 'pathname'
require 'sshkit'
require 'sshkit/sudo'
include SSHKit::DSL

require_relative './provision_like_task.rb'

declare_provision_like_task(:deploy,
                            "Deploys everything to every server",
                            "shared_args",
                            "source_folders",
                            "provisioning")
