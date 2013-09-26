require 'kit/helpers'
require 'kit/ssh_keys'

module Kit
  class Knife
    include Kit::Helpers

    attr_accessor :server

    def initialize(server)
      self.server = server
    end

    def upload_secret
      destination_path = '/tmp/encrypted_data_bag_secret'
      secret_path = SSHKeys.knife_secret.path

      report "Copying encrypted data bag secret..." do
        cmd = %{scp -o "StrictHostKeyChecking=false"}
        cmd += " -i #{server.ssh_key}" if server.ssh_key
        cmd += " -P #{server.ssh_port}" if server.ssh_port
        cmd += " #{secret_path} #{server.chef_user}@#{server.ip}:#{destination_path}"
        shellout cmd
      end
    end

    def node_type(build = true)
      node_type = "#{server.site}-#{server.type}"
      node_type = node_type + "-launch" unless build
      node_type
    end

    def bootstrap_chef(build = true)
      destination_path = '/tmp/encrypted_data_bag_secret'

      cmd = "bundle exec knife solo bootstrap #{server.chef_user}@#{server.ip}"
      cmd += " -N #{node_type(build)}"
      cmd += " -i #{server.ssh_key}" if server.ssh_key
      cmd += " -p #{server.ssh_port}" if server.ssh_port
      if server.cloud == :smart_os
        cmd += ' --template-file config/joyent-smartmachine.erb'
      end
      shellout cmd
    end

    def cook
      cmd = "bundle exec knife solo cook #{server.chef_user}@#{server.ip}"
      cmd += " -N #{node_type}"
      cmd += " -i #{server.ssh_key}" if server.ssh_key
      cmd += " -p #{server.ssh_port}" if server.ssh_port
      shellout cmd
    end
  end
end
