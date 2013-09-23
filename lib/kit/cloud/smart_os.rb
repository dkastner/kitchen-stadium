require 'net/ssh'

module Kit
  module SmartOS
    def destroy
      Net::SSH.start('houston', 'root') do |ssh|
        puts ssh.exec! "vmadm destroy #{instance_id}"
      end
    end

    def self.list_instances
      Net::SSH.start('houston', 'root') do |ssh|
        puts ssh.exec! "vmadm list"
      end
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

    def create_instance
      instance_id = nil
      config['nics'].first['ip'] = host['ip']

      Net::SSH.start('houston', 'root') do |ssh|
        puts ssh.exec! "imgadm import #{image}"
        puts "vmadm create <<-EOF\n#{config.to_json}\nEOF"
        data = ssh.exec! "vmadm create <<-EOF\n#{config.to_json}\nEOF"
        puts data
        instance_id = data.scan(/VM (.*)/).flatten.last
        copy_key(ssh) if respond_to?(:copy_key)
      end
      self.instance_id = instance_id

      fail 'Creation failed' if instance_id.nil?

      Kit.copy_node_config(site, type, ip)
      puts "Created host #{instance_id}@#{host['ip']} with image #{image}"

      instance_id
    end

    def nic_config
      {
        'nics' => [
          {
            'nic_tag' => 'admin',
            'model'   => 'virtio',
            'ip'      => host['ip'],
            'netmask' => '255.255.255.0',
            'gateway' => '192.168.1.254',
            'primary' => 1
          }
        ]
      }
    end

    module SmartMachine 
      include SmartOS

      IMAGE = 'f669428c-a939-11e2-a485-b790efc0f0c1'

      ZONES = {
        'dev' => {
          'brand' => 'joyent',
          'alias' => 'app',
          'ram' => 1024
        },

        'importer' => {
          'brand' => 'joyent',
          'alias' => 'app-importer',
          'ram' => 1024
        },

        'solr' => {
          'brand' => 'joyent',
          'alias' => 'app-solr',
          'ram' => 256
        }
      }

      def create_instance
        smartos = new site, type, host
        smartos.create_instance
      end

      def copy_key(ssh)
        puts ssh.exec! "cp /root/.ssh/authorized_keys /zones/#{instance_id}/root/root/.ssh/"
      end

      def image; IMAGE; end

      def config
        @config ||= ZONES[type].merge(nic_config).merge({
          'image_uuid' => IMAGE
        })
      end
    end

    module Ubuntu
      include SmartOS

      IMAGE = 'd2ba0f30-bbe8-11e2-a9a2-6bc116856d85'

      ZONES = {
        'dev' => {
          'brand' => 'kvm',
          'alias' => 'app',
          'ram' => 2048,
          'vcpus' => 2,
          'resolvers' => [
            '192.168.1.254'
          ],
        },
        'importer' => {
          'brand' => 'kvm',
          'alias' => 'app-importer',
          #'ram' => 2024,
          'vcpus' => 2,
          'resolvers' => [
            '192.168.1.254'
          ]
        },
        'solr' => {
          'brand' => 'kvm',
          'alias' => 'app-solr',
          'ram' => 256,
          'vcpus' => 1,
          'resolvers' => [
            '192.168.1.254'
          ]
        }
      }

      def create_instance
        ubuntu = new site, type, host
        ubuntu.create_instance
      end

      def image; IMAGE; end

      def disk_config
        {
          'disks' => [
            {
              'image_uuid' => IMAGE,
              'boot' => true,
              'model' => 'virtio',
              'size' => 12000
            }
          ]
        }
      end

      def config
        @config ||= ZONES[type].merge({
          "customer_metadata" => {
            "root_authorized_keys" => File.read("#{ENV['HOME']}/.ssh/id_rsa.pub")
          }
        }).merge(nic_config).merge(disk_config)
      end
    end
  end
end
