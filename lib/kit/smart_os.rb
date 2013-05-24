require 'net/ssh'

module Kit
  class SmartOS
    include Kit::Helpers

    def self.delete_instance(instance_id)
      Net::SSH.start('houston', 'root') do |ssh|
        puts ssh.exec! "vmadm destroy #{instance_id}"
      end
    end

    def self.list_instances
      Net::SSH.start('houston', 'root') do |ssh|
        puts ssh.exec! "vmadm list"
      end
    end

    attr_accessor :site, :type, :host, :instance_id, :image

    def initialize(site, type, host)
      self.site = site
      self.type = type
      self.host = host
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

    class SmartMachine < SmartOS
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
        }
      }

      def self.create_instance(site, type, host)
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

    class Ubuntu < SmartOS
      IMAGE = 'da144ada-a558-11e2-8762-538b60994628'

      ZONES = {
        'dev' => {
          'brand' => 'kvm',
          'alias' => 'app',
          'ram' => 1024,
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
        }
      }

      def self.create_instance(site, type, host)
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
