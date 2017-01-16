namespace :run do
  ($conf['run'] || {}).each do |task_name, command_spec|
    if command_spec.is_a? Hash
      desc command_spec['command']
      task task_name.to_sym, :server do |task, args|
        cmd_hosts = hosts(args)
        if command_spec['mode'] == 'once'
          cmd_hosts = [cmd_hosts.first]
        end
        on cmd_hosts do |host|
          sudo command_spec['command']
        end
      end
    else
      desc command_spec
      task task_name.to_sym, :server do |task, args|
        on hosts(args) do |host|
          sudo command_spec
        end
      end
    end
  end
end