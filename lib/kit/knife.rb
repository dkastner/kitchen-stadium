require 'kit/helpers'

module Kit
  class Knife
    include Kit::Helpers

    KNIFE_SECRET_PATH = '~/.ssh/app-knife.pem'

    attr_accessor :server

    def initialize(server)
      self.server = server
    end

    def upload_secret
      destination_path = '/tmp/encrypted_data_bag_secret'
      secret_path = ENV['KNIFE_SECRET_PATH'] || KNIFE_SECRET_PATH

      report "Copying encrypted data bag secret..." do
        cmd = %{scp -o "StrictHostKeyChecking=no"}
        cmd += " -i #{server.ssh_key}" if server.ssh_key
        cmd += " #{secret_path} #{server.user}@#{server.ip}:#{destination_path}"
        shellout cmd
      end
    end

    def bootstrap_chef(build = true)
      destination_path = '/tmp/encrypted_data_bag_secret'
      secret_path = ENV['KNIFE_SECRET_PATH'] || KNIFE_SECRET_PATH

      node_type = "#{server.site}-#{server.type}"
      node_type = node_type + "-launch" unless build

      cmd = "bundle exec knife solo bootstrap #{server.user}@#{server.ip} -N #{node_type}"
      cmd += " -i #{server.ssh_key}" if server.ssh_key
      if server.platform.to_s == 'smartos_smartmachine'
        cmd += ' --template-file config/joyent-smartmachine.erb'
      end
      shellout cmd
    end

    def cook
      shellout "bundle exec knife solo cook ubuntu@#{server.ip} -i ~/.ssh/app-ssh.pem"
    end
  end
end
