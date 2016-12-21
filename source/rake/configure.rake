require_relative './provision_like_task.rb'

declare_provision_like_task(:configure,
                            "Configures every server",
                            "shared_configure_args",
                            "configure_folders",
                            "configuring",
                            bootstrap: true)
