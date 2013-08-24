require 'kit'
require 'kit/amazon'
require 'kit/knife'
require 'kit/smart_os'

module Kit
  class Server
    include Kit::Helpers

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

    def self.find_color(site, type)
      list = site == 'kitchen-stadium' ?
        %w{kaga dacascos} :
        %w{red orange yellow green blue purple brown white black}

      color = (list - ServerList.running_colors(site, type)).first
      raise "I'm out of colors!" if color.nil?
      color
    end

    def self.from_scratch(site, type, color = nil)
      color ||= find_color(site, type)
      server = Server.new site, type, color

      server.create_instance
      fail "Failed to create instance" unless server.instantiated?

      server.register_known_host
      server.upload_secret

      server
    end

    def self.launch(site, type, color = nil)
      color ||= find_color(site, type)
      server = Server.new site, type, color

      server.launch_image
      fail "Failed to create instance" unless server.instantiated?

      server.register_known_host
      server.upload_secret

      server
    end

    attr_accessor :site, :type, :color, :instance_id, :ip, :log, :zone,
      :created_at, :status, :static_ip, :image, :platform

    def initialize(site, type, color, attrs = {})
      self.site = site
      self.type = type
      self.color = color
      self.log = ""

      attrs.each do |field, value|
        self.send("#{field}=", value)
      end

      actualize!
    end

    def id
      sig = [site, type, color]
      sig << instance_id if instance_id
      sig << ip if !instance_id && ip
      sig << image if image
      sig.join('-')
    end

    def config
      return @config unless @config.nil?
      
      begin
        @config = Kit.hosts[site][type]['_default'].merge(
          Kit.hosts[site][type][color] || {})
      rescue NoMethodError => e
        @config = {}
      end
    end

    def platform
      @platform ||= config['platform'] ? config['platform'].to_sym : nil
    end

    def image
      config['image']
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
        days = (Time.now.to_i - created_at.to_i) / 60 / 60 / 24
        hours = ((Time.now.to_i - created_at.to_i) / 60 / 60) - (days * 24)
        mins = ((Time.now.to_i - created_at.to_i) / 60) - (hours * 60) - (days * 24 * 60)
        sprintf "%3dd %2dh %2dm", days, hours, mins
      end
    end

    def instance_id
      @instance_id ||= config['instance_id'] ||
      @instance_id ||= find_instance_id_by_ip if respond_to?(:find_instance_id_by_ip)
      @instance_id ||= find_instance_id_by_label if respond_to?(:find_instance_id_by_label)
    end

    def instance_name
      [site, type, color].join('-')
    end

    def find_instance_id_by_label
    end

    def status_line
      display_color = color == '_default' ? '*' : color
      [site, type, display_color, status, ip, instance_id, uptime]
    end

    def instantiated?
      !instance_id.nil?
    end

    def running?
      status == 'running'
    end

    def knife
      @knife ||= Knife.new self
    end

    def create_instance
      raise "Can't create instance: No configuration found for #{instance_name}"
    end

    def upload_secret
      knife.upload_secret
    end

    def bootstrap_chef
      knife.bootstrap_chef
    end

    def cook
      knife.cook
    end

    def deploy
      shellout "cap #{site} #{type} #{color} process"
    end

    def register_known_host
      shellout "ssh-keygen -R #{ip}"
    end

    def actualize!
      if platform
        mod = case platform
        when :smartos_smartmachine then
          SmartOS::SmartMachine
        when :smartos_ubuntu then
          SmartOS::Ubuntu
        else
          Amazon
        end
        extend mod
      end
    end
  end
end
