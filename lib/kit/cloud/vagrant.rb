require 'fog'

module Kit
  module Cloud
    module Vagrant

      BOXES = {
        u1204_64_us_east: 'ami-fd20ad94'
      }

      #def self.vm
        #@vm ||= Fog::Compute.new(provider: :libvirt,
                                 #libvirt_uri: 'vbox:///session')
      #end

      #def vm_server
        #@vm_server ||= Vagrant.vm.servers.find { |s| s.id == instance_id }
      #end
      #def vm_server=(val)
        #@vm_server = val
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


        update_info!(vm_server)
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
          data = Amazon.vm.create_image(instance_id, image_name,
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
        vm_server.destroy
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
