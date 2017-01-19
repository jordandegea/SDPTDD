require 'sshkit'
require 'digest/sha1'
require 'securerandom'

module SSHKit
  class Command
    def uuid
      @uuid ||= "#{host.properties.name}/#{Digest::SHA1.hexdigest(SecureRandom.random_bytes(10))[0..7]}"
    end
  end
end
