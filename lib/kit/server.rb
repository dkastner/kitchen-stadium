require 'kit'
require 'kit/amazon'
require 'kit/knife'
require 'kit/smart_os'

module Kit
  class Server
    include Kit::Helpers

    AMIS = {
      u1204_64_us_east: 'ami-fd20ad94',
      inspire_www_latest: 'ami-328a165b'
    }

    def self.find_by_ip(ip)
      found = nil
      Kit.hosts.each do |site, types|
        types.each do |type, hosts|
          hosts.each do |color, data|
            found = Server.new(site, type, color) if data['static_ip'] == ip
          end
        end
      end
      found
    end

    attr_accessor :site, :type, :color, :instance_id, :ip, :log, :zone,
      :created_at, :status, :static_ip

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

    def platform
      config['platform'].to_sym
    end
    def platform_helper
      case platform
      when :amazon
        Amazon
      when :smartos_smartmachine then
        SmartOS::SmartMachine
      when :smartos_ubuntu then
        SmartOS::Ubuntu
      else
        Amazon
      end
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
      @zone ||= config['zone']
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

    def uptime
      if created_at
        hours = (Time.now.to_i - created_at.to_i) / 60 / 60
        mins = ((Time.now.to_i - created_at.to_i) / 60) - (hours * 60)
        "#{hours}h#{mins}m"
      end
    end

    def instance_id
      @instance_id ||= config['instance_id'] ||
        find_instance_id_by_ip ||
        find_instance_id_by_label
    end

    def instance_name
      [site, type, color].join('-')
    end

    def find_instance_id_by_ip
      Amazon.instance_id(ip) if ip
    end

    def find_instance_id_by_label
    end

    def status_line
      [site, type, color, status, ip, instance_id, uptime]
    end

    def update_info!(real_server)
      self.instance_id = real_server.id
      self.ip = real_server.public_ip_address
      self.zone = real_server.availability_zone
      self.created_at = real_server.created_at
      self.status = real_server.state
    end

    def create_instance
      self.instance_id = platform_helper.create_instance site, type, config
    end

    def instantiated?
      !instance_id.nil?
    end

    def running?
      status == 'running'
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
      knife.cook ip
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
      if instance_id.nil? || instance_id == ''
        raise "No instance found for #{id}!"
      end
      platform_helper.delete_instance instance_id
    end
  end
end

