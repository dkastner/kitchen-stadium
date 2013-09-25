require 'fog'

module Kit
  module Cloud
    module Vagrant

      COLORS = %w{boxcar cholly yegg skunk jones}

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

      def self.server_list
        raw_list = `vagrant status`.split(/\n/)[2..-1].
          map { |line| line.strip }.
          map { |line| line.split(/\s+/) }.
          find_all { |row| row.count == 3 }

        vagrant_servers = raw_list.inject({}) do |hsh, row|
          name, status, source = row
          hsh[name] ||= []
          hsh[name] << status
          hsh
        end

        servers = []
        Kit.hosts.each do |site, types|
          types.each do |type, hosts|
            hosts.each do |color, data|
              server = Server.new site, type, color
              if subset = vagrant_servers.delete(server.instance_name)
                subset.each do |status|
                  s = Server.new site, type, color, cloud: :vagrant
                  s.update_info!(status)
                  servers << s
                end
              else
                servers << server
              end
            end
          end
        end

        remaining = vagrant_servers.map do |instance_name, subset|
          subset.each do |status|
            site, type, color = instance_name.split('-')
            server = Server.new(site, type, color, cloud: :vagrant)
            server.update_info!(status)

            servers << server
          end
        end

        servers
      end

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
        shellout "vagrant up #{label}"

        update_info!('running')
      end
      def launch_image
        create_instance
        register_known_host
        upload_secret
      end

      def update_info!(status)
        self.status = status
        if status == 'running'
          info = `vagrant ssh-config #{label}`.split(/\n/)
          info.each do |line|
            property, value = line.strip.split(/\s/)
            case property
            when 'HostName'
              self.ip = value
            when 'Port'
              self.ssh_port = value
            when 'IdentityFile'
              self.ssh_key = value
            when 'User'
              self.chef_user = value
            end
          end
        end
      end

      def destroy!
        unless running?
          raise "No instance found for #{id}!"
        end
        shellout "vagrant destroy -f #{label}"
      end
    end
  end
end
