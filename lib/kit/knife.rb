require 'kit/helpers'

module Kit
  class Knife
    include Kit::Helpers

    def self.upload_secret(host)
      knife = new nil, nil, host
      knife.upload_secret
    end

    KNIFE_SECRET_PATH = '~/.ssh/knife.pem'

    attr_accessor :site, :type, :host

    def initialize(site, type, host)
      self.site = site
      self.type = type
      self.host = host
    end

    def upload_secret
      ssh_key = host['ssh_key']
      user = host['chef_user']
      ip = host['ip']
      destination_path = '/tmp/encrypted_data_bag_secret'
      secret_path = ENV['KNIFE_SECRET_PATH'] || KNIFE_SECRET_PATH

      report "Copying encrypted data bag secret..." do
        cmd = %{scp -o "StrictHostKeyChecking=no"}
        cmd += " -i #{ssh_key}" if ssh_key
        cmd += " #{secret_path} #{user}@#{ip}:#{destination_path}"
        `#{cmd}`
      end
    end

    def bootstrap
      platform = host['platform']
      ssh_key = host['ssh_key']
      user = host['chef_user']
      ip = host['ip']
      destination_path = '/tmp/encrypted_data_bag_secret'
      secret_path = ENV['KNIFE_SECRET_PATH'] || KNIFE_SECRET_PATH

      cmd = "bundle exec knife solo bootstrap #{user}@#{ip} -N #{site}-#{type}"
      cmd += " -i #{ssh_key}" if ssh_key
      if platform == 'smartos_smartmachine'
        cmd += ' --template-file config/joyent-smartmachine.erb'
      end

      exec cmd
    end
  end
end
