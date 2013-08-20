require 'kit'
require 'kit/knife'

module Kit
  class Server
    include Kit::Helpers

    AMIS = {
      u1204_64_us_east: 'ami-fd20ad94',
      inspire_www_latest: 'ami-328a165b'
    }

    attr_accessor :site, :type, :color, :instance_id, :ip, :log

    def initialize(site, type, color)
      self.site = site
      self.type = type
      self.color = color
      self.log = ""
    end

    def id
      sig = [site, type, color]
      sig << instance_id if instance_id
      sig << ip if !instance_id && ip
      sig << image if image
      sig.join('-')
    end

    def config
      begin
        @config ||= Kit.hosts[site][type][color]
      rescue NoMethodError => e
        site_found = !Kit.hosts[site].nil?
        type_found = site_found && !Kit.hosts[site][type].nil?
        color_found = type_found && !Kit.hosts[site][type][color].nil?
        fail "Unable to find server #{site}(#{site_found})/#{type}(#{type_found})/#{color}(#{color_found})"
      end
    end

    def ip
      @ip ||= config['ip']
    end
    def ip=(val)
      @ip = val
      config['ip'] = val
    end

    def platform
      config['platform'].to_sym
    end

    def image
      config['image'] || AMIS[platform]
    end
    def image=(val)
      @image = val
      config['image'] = val
    end

    def user
      config['user'] || 'ubuntu'
    end

    def zone
      config['zone']
    end

    def security_groups
      config['security_groups']
    end

    def ssh_key
      config['ssh_key']
    end

    def instance_type
      config['instance_type']
    end

    def chef_user
      config['chef_user']
    end

    def instance_id
      @instance_id ||= config['instance_id'] ||
        find_instance_id_by_ip ||
        find_instance_id_by_label
    end

    def find_instance_id_by_ip
      Amazon.instance_id(ip) if ip
    end

    def find_instance_id_by_label
    end

    def create_instance
      self.ip = nil

      case platform
      when :smartos_smartmachine then
        self.instance_id = SmartOS::SmartMachine.create_instance site, type, config
      when :smartos_ubuntu then
        self.instance_id = SmartOS::Ubuntu.create_instance site, type, config
      else
        self.instance_id = Amazon.create_instance self
        self.ip = `bin/kit list_instances amazon | grep #{instance_id} | awk '{print $2;}'`.chomp
      end

      save if ip
    end

    def instantiated?
      !instance_id.nil?
    end

    def wait
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

    def knife
      @knife ||= Knife.new site, type, config
    end

    def bootstrap
      knife.upload_secret
      knife.bootstrap
    end

    def cook
      shellout "bundle exec knife solo cook ubuntu@#{ip} -i ~/.ssh/app-ssh.pem"
    end

    def deploy
      shellout "cap #{site} #{type} #{color} deploy_#{site}_#{type.gsub(/-/, '_')}"
    end

    def create_image!
      self.image = Amazon.image self
      save
    end

    def save
      Kit.update_host(site, type, color, config)
      true
    end

    def register_known_host
      shellout "ssh-keygen -R #{ip}"
    end

    def destroy!
      raise "No instance found for #{id}!" if instance_id.blank?
      Amazon.delete_instance instance_id
      self.instance_id = nil
      self.ip = nil
      save
    end
  end
end

