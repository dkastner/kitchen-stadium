require 'kit'
require 'kit/cloud'
require 'kit/knife'

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

    def self.find_color(site, type, options)
      list = if site == 'kitchen-stadium'
        %w{kaga dacascos}
      elsif options[:cloud].to_sym == :vagrant
        Cloud::Vagrant::COLORS
      else
        Kit::COLORS
      end

      color = (list - ServerList.running_colors(site, type)).first
      raise "I'm out of colors!" if color.nil?
      color
    end

    def self.from_scratch(site, type, color = nil, options = {})
      color ||= find_color(site, type, options)
      server = Server.new site, type, color

      server.create_instance(true)
      fail "Failed to create instance" unless server.instantiated?

      server.register_known_host
      server.upload_secret

      server
    end

    def self.launch(site, type, color = nil, options = {})
      color ||= find_color(site, type, options)
      server = Server.new site, type, color, options

      server.launch_image
      fail "Failed to create instance" unless server.instantiated?

      server.register_known_host
      server.upload_secret

      server
    end

    def self.config_var(name, default = nil, format = nil)
      attr_accessor name
      define_method name do
        ivar = "@#{name}"
        result = if val = instance_variable_get(ivar)
          val
        else
          val = (config[name.to_s] || default)
          instance_variable_set ivar, val
          val
        end

        if format && result.respond_to?(format)
          result.send format
        else
          result
        end
      end
    end

    config_var :cloud, Kit.default_cloud, :to_sym
    config_var :image
    config_var :ssh_key
    config_var :ssh_port, 22
    config_var :chef_user, 'ubuntu'

    attr_accessor :site, :type, :color, :instance_id, :ip, :log, :zone,
      :created_at, :status, :static_ip

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

    def label
      [site, type, color].join('-')
    end

    def id
      sig = [label]
      sig << instance_id if instance_id
      sig << ip if !instance_id && ip
      sig << image if image
      sig.join('-')
    end

    def config
      return @config unless @config.nil?
      
      site_config = Kit.hosts[site] || {}
      type_config = site_config[type] || {}
      default_config = type_config['_default'] || {}
      begin
        @config = default_config.merge(
          Kit.hosts[site][type][color] || {})
      rescue NoMethodError => e
        @config = {}
      end
    end

    def zone
      @zone ||= config['zone']
    end

    def security_groups
      config['security_groups']
    end

    def instance_type
      config['instance_type']
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
      [site, type, display_color, cloud, status, ip, instance_id, uptime]
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

    def bootstrap_chef(build = true)
      upload_secret
      knife.bootstrap_chef build
    end

    def cook
      knife.cook
    end

    def deploy
      shellout "cap #{site} #{type} #{color} process"
    end

    def run(cmd)
      cmd = if cmd =~ /[;&]/
              cmd
            else
              "rake #{cmd}"
            end

      shellout %{cap #{site} #{type} #{color} invoke COMMAND="#{cmd}"}
    end

    def register_known_host
      raise "no ip" if ip.nil?
      shellout "ssh-keygen -R #{ip}"
    end

    def actualize!
      mod = case cloud
      when :amazon then
        Cloud::Amazon
      when :smartos then
        Cloud::SmartOS
      else
        Cloud::Vagrant
      end
      extend mod
    end
  end
end
