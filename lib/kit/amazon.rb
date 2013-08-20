require 'kit/helpers'
require 'fog'

module Kit
  module Amazon
    extend Kit::Helpers

    KEY_PAIRS = {
      'kitchen-stadium' => 'app-catalog',
      'app' => 'app-catalog',
      'inspire' => 'inspire-www'
    }

    def self.aws
      @aws ||= Fog::Compute.new({
        :provider                 => 'AWS',
        :aws_access_key_id        => ENV['AWS_ACCESS_KEY_ID'],
        :aws_secret_access_key    => ENV['AWS_SECRET_ACCESS_KEY']
      })
    end


    def self.create_instance(server)
      instance_type = server.instance_type
      key = KEY_PAIRS[server.site] || server.site

      cmd = "bundle exec knife ec2 server create -f #{server.instance_type} -I #{server.image} -Z #{server.zone} -S #{key} -G #{server.security_groups} -N #{server.site}-#{server.type}-#{server.color} --ssh-user=#{server.user} -i #{server.ssh_key}"
      cmd += "--elastic-ip #{server.ip}" if server.ip

      puts cmd
      cmd_data = sh cmd
      puts cmd_data

      instance_id = if item = cmd_data.split(/:/).last
        item.chomp
      end

      instance_id
    end

    def self.delete_instance(instance_id)
      puts `knife ec2 server delete #{instance_id} -y`
    end

    def self.list_instances
      puts `knife ec2 server list`
    end

    def self.image(server)
      image_name = "#{server.id}-#{Time.now.strftime('%Y%m%d%h%m%s')}"
      data = nil
      begin
        data = aws.create_image(server.instance_id, image_name,
                                'Created automatically by Kitchen Stadium')
      rescue => e
        puts e.response.inspect
        puts e.inspect
        raise e
      end
      data.body['imageId']
    end

    def self.instance_id(host_ip)
      info = `bin/kit list_instances ec2 | grep #{host_ip}`
      info.split(/\s/).first
    end
  end
end
