require 'kit/helpers'

module Kit
  module Amazon
    extend Kit::Helpers

    KEY_PAIRS = {
      'app' => 'app-catalog',
      'inspire' => 'inspire-www'
    }

    def self.create_instance(site, type, color, host, image)
      instance_type = host['instance_type']
      user = host['user'] || 'ubuntu'
      key = KEY_PAIRS[site] || site

      cmd = "bundle exec knife ec2 server create -f #{instance_type} -I #{image} -Z #{host['zone']} -S #{key} -G #{host['security_groups']} -N #{site}-#{type}-#{color} --ssh-user=#{user} -i #{host['ssh_key']}"
      cmd += "--elastic-ip #{host['ip']}" if host['ip']

      puts cmd
      data = sh cmd
      puts data
      if item = data.split(/:/).last
        item.chomp
      end
    end

    def self.delete_instance(instance_id)
      puts `knife ec2 server delete #{instance_id} -y`
    end

    def self.list_instances
      puts `knife ec2 server list`
    end
  end
end
