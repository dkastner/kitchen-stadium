module Kit
  module Amazon
    def self.create_instance(site, type, host)
      instance_type = host['instance_type']
      data = sh("bundle exec knife ec2 server create -f #{instance_type} -I #{host['platform']} -Z #{host['zone']} -S #{type} -G #{host['security_groups']} -N #{type} --ssh-user=#{host['user']} -i #{host['ssh_key']} --elastic-ip #{host['ip']}")
      data.split(/:/).last.chomp
    end

    def self.delete_instance(instance_id)
      puts `knife ec2 server delete #{instance_id} -y`
    end

    def self.list_instances
      puts `knife ec2 server list`
    end
  end
end
