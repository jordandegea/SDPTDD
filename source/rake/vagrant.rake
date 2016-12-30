if $environment == 'development'
  def vagrant(*args)
    Dir.chdir "vagrant" do
      sh "vagrant", *args
    end
  end

  namespace :vagrant do
    desc "Starts the virtual machines"
    task :up do
      vagrant "up"
    end

    desc "Stops the virtual machines"
    task :halt do
      vagrant "halt"
    end

    desc "Destroys the virtual machines"
    task :destroy do
      vagrant "destroy", "-f"
    end

    desc "Destroys and restarts the machines"
    task :reup => %w(vagrant:destroy vagrant:up)
  end
end
