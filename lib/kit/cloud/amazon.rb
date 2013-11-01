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

      def self.server_list
        aws_servers = aws.servers.inject({}) do |hsh, server|
          key = server.tags['Name']
          hsh[key] ||= []
          hsh[key] << server
          hsh
        end

        servers = []
        Kit.hosts.each do |site, types|
          types.each do |type, hosts|
            hosts.each do |color, data|
              server = Server.new site, type, color
              if subset = aws_servers.delete(server.instance_name)
                subset.each do |aws_server|
                  s = Server.new site, type, color, cloud: :amazon
                  s.update_info!(aws_server)
                  servers << s
                end
              else
                servers << server
              end
            end
          end
        end

        remaining = aws_servers.map do |instance_name, subset|
          if instance_name
            subset.each do |aws_server|
              site, type, color = instance_name.split('-')
              server = Server.find_by_ip aws_server.public_ip_address
              server ||= Server.new(site, type, color, cloud: :amazon)
              server.update_info!(aws_server) if server.respond_to?(:update_info!)

              servers << server
            end
          end
        end

        servers
      end

      def self.aws
        return @aws unless @aws.nil?

        @aws = Fog::Compute.new({
          :provider                 => 'AWS',
          :aws_access_key_id        => ENV['AWS_ACCESS_KEY'],
          :aws_secret_access_key    => ENV['AWS_ACCESS_SECRET']
        })

        @aws
      end

      def private_key_name
        'AWS_SSH_PRIVATE'
      end

      def aws_server
        @aws_server ||= Amazon.aws.servers.find { |s| s.id == instance_id }
      end
      def aws_server=(val)
        @aws_server = val
      end

      def with_keys(&blk)
        SSHKeys.with_keys('AWS_SSH_PUBLIC', 'AWS_SSH_PRIVATE') do |pub, priv|
          blk.call pub, priv
        end
      end

      def ssh(cmd)
        with_private_key do |private_key_path|
          aws_server.username = deploy_user
          aws_server.ssh [cmd], keys: [private_key_path]
        end
      end

      def wait
        aws_server.wait
      end

      def create_instance(default_image = false)
        key = KEY_PAIRS[site] || site
        image_id = default_image ? AMIS[:u1204_64_us_east] : image
        image_id ||= AMIS[:u1204_64_us_east]

        with_keys do |pub_key, priv_key|
          attrs = {
            flavor_id: instance_type,
            image_id: image_id,
            availability_zone: zone,
            security_groups: security_groups,
            tags: { 'Name' => instance_name },
            username: chef_user,
            key_name: key,
            private_key_path: priv_key,
            public_key_path: pub_key
          }
          attrs[:elastic_ip] = static_ip if static_ip

          self.aws_server = Amazon.aws.servers.bootstrap attrs
        end

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
