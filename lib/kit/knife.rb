require 'kit/helpers'

module Kit
  module Knife
    extend Kit::Helpers

    def self.upload_secret(host)
      knife = new host
      knife.upload_secret
    end

    KNIFE_SECRET_PATH = '~/.ssh/knife.pem'

    attr_accessor :host

    def initialize(host)
      self.host = host
    end

    def upload_secret
      ssh_key = host['ssh_key']
      user = host['chef_user']
      ip = host['ip']
      destination_path = '/tmp/encrypted_data_bag_secret'
      secret_path = ENV['KNIFE_SECRET_PATH'] || KNIFE_SECRET_PATH

      report "Copying encrypted data bag secret..." do
        puts `scp -i #{ssh_key} #{secret_path} #{chef_user}@#{ip}:#{destination_path}`
      end
    end

    def bootstrap
      platform = host['platform']
      ssh_key = host['ssh_key']
      user = host['chef_user']
      ip = host['ip']
      destination_path = '/tmp/encrypted_data_bag_secret'
      secret_path = ENV['KNIFE_SECRET_PATH'] || KNIFE_SECRET_PATH

      cmd = "bundle exec knife solo bootstrap #{user}@#{ip}"
      cmd += " -i #{ssh_key}" if ssh_key
      if platform == 'smartos_smartmachine'
        cmd += ' --template-file config/joyent-smartmachine.erb'
      end

      sh cmd
    end
  end
end
