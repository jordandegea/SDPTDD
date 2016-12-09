namespace :run do
  ($conf['run'] || {}).each do |task_name, command|
    desc command
    task task_name.to_sym, :server do |task, args|
      on hosts(args) do |host|
        sudo command
      end
    end
  end
end