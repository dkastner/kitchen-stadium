require 'fog'

module Kit
  module Cloud
    module Amazon
      KEY_PAIRS = {
        'kitchen-stadium' => 'app-catalog',
        'app' => 'app-catalog',
        'inspire' => 'inspire-www'
      }

      AMIS = {
        u1204_64_us_east: 'ami-fd20ad94',
        inspire_www_latest: 'ami-328a165b'
      }

      def self.aws
        return @aws unless @aws.nil?

        @aws = Fog::Compute.new({
          :provider                 => 'AWS',
          :aws_access_key_id        => ENV['AWS_ACCESS_KEY'],
          :aws_secret_access_key    => ENV['AWS_ACCESS_SECRET']
        })
        Fog.credentials.merge!({
          private_key_path: "#{ENV['HOME']}/.ssh/app-ssh.pem",
          public_key_path: "#{ENV['HOME']}/.ssh/app-ssh.pub"
        })

        @aws
      end

      def aws_server
        @aws_server ||= Amazon.aws.servers.find { |s| s.id == instance_id }
      end
      def aws_server=(val)
        @aws_server = val
      end

      #def wait
        #aws_server.wait
      #end
      def wait
        ip = static_ip
        report "Waiting for server #{ip}", 'ready!' do
          waiting = true
          while waiting
            status = ''
            cmd = "ssh -y"
            cmd += " -i #{ssh_key}" if ssh_key
            cmd += %{ -o "ConnectTimeout=5" -o "StrictHostKeyChecking=false" #{chef_user}@#{ip} "echo OK"}
            IO.popen(cmd) do |ssh|
              status += ssh.gets.to_s
            end
            if waiting = (status !~ /OK/)
              sleep 1
            end
            dot
          end
        end
        yield if block_given?
      end

      def create_instance(default_image = false)
        key = KEY_PAIRS[site] || site
        image_id = default_image ? AMIS[:u1204_64_us_east] : image
        image_id ||= AMIS[:u1204_64_us_east]

        attrs = {
          flavor_id: instance_type,
          image_id: image_id,
          availability_zone: zone,
          security_groups: security_groups,
          tags: { 'Name' => instance_name },
          username: user,
          key_name: key
        }
        attrs[:elastic_ip] = static_ip if static_ip

        self.aws_server = Amazon.aws.servers.bootstrap attrs

        update_info!(aws_server)
      end
      def launch_image
        create_instance
        register_known_host
        upload_secret
      end

      def update_info!(real_server)
        self.instance_id = real_server.id
        self.ip = real_server.public_ip_address
        self.zone = real_server.availability_zone
        self.created_at = real_server.created_at
        self.status = real_server.state
      end

      def create_image!
        image_name = "#{id}-#{Time.now.strftime('%Y%m%d-%H%M')}"
        data = nil
        begin
          data = Amazon.aws.create_image(instance_id, image_name,
                                  'Created automatically by Kitchen Stadium')
        rescue => e
          puts e.response.inspect
          puts e.inspect
          raise e
        end

        self.image = data.body['imageId']

        data = Kit.hosts[site][type]['_default'].merge 'image' => image
        Kit.update_host(site, type, '_default', data)

        image
      end

      def destroy!
        if instance_id.nil? || instance_id == ''
          raise "No instance found for #{id}!"
        end
        aws_server.destroy
      end


      def find_instance_id_by_ip
        if ip
          server = ServerList.find_by_ip(ip)
          server.instance_id
        end
      end
    end
  end
end
