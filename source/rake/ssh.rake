desc "Opens an SSH shell to the given host"
task :ssh do |task, args|
  # shift everything until ssh so we can rake --trace --smth ssh
  while ARGV.first =~ /^(-|ssh$)/
    break if ARGV.shift == 'ssh'
  end

  # Find the host
  host = $hosts[ARGV.first]
  raise "#{ARGV.first} not found" unless host

  # Run SSH command
  sh "ssh", "-o", "StrictHostKeyChecking=no", "-i", host.ssh_options[:keys].first, "#{host.user}@#{host.hostname}"

  # https://stackoverflow.com/questions/3586997/how-to-pass-multiple-parameters-to-rake-task
  #
  # By default, rake considers each 'argument' to be the name of an actual task.
  # It will try to invoke each one as a task.  By dynamically defining a dummy
  # task for every argument, we can prevent an exception from being thrown
  # when rake inevitably doesn't find a defined task with that name.
  ARGV.each do |arg|
    task arg.to_sym do
    end
  end
end