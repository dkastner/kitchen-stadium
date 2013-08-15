require 'json'
require 'thor'

require 'kit/amazon'
require 'kit/helpers'
require 'kit/knife'
require 'kit/server'
require 'kit/smart_os'

module Kit
  class CLI < Thor
    include Kit::Helpers

    attr_accessor :host, :instance_id, :execution_mode

    APP_SOLR_CLIENTS = %w{app-admin app-catalog}
    STATSD_CLIENTS = %w{stats}
    COLLECTD_CLIENTS = %w{app-solr}

    desc 'list', 'list all hosts'
    def list
      require 'terminal-table'
      items = []
      items << ['Site', 'Type', 'Color', 'IP']
      Kit.hosts.each do |site, types|
        types.each do |type, hosts|
          hosts.each do |name, data|
            items << [site, type, name, data['ip']]
          end
        end
      end
      table = Terminal::Table.new :rows => items
      puts table
    end

    desc 'create_instance SITE TYPE COLOR',
      'create a new ec2 instance, e.g. `app solr red'
    def create_instance(site, type, color)
      server = Server.new site, type, color

      report 'Creating instance...' do
        server.create_instance
      end

      fail "Failed to create instance" unless server.instantiated?

      logger.info "Created host #{site}-#{type}-#{color}@#{server.ip} (#{server.instance_id})"

      server.register_known_host

      server.wait do
        server.bootstrap
      end
    end

    desc 'list_instances PLATFORM', 'list running instances'
    def list_instances(platform)
      if platform =~ /amazon/ || platform =~ /ec2/
        Amazon.list_instances
      else
        SmartOS.list_instances
      end
    end

    desc 'upload_knife_secret SITE TYPE COLOR [IP]', 'upload ~/.ssh/knife.pem to server'
    def upload_knife_secret(site, type, color, ip = nil)
      host = Kit.hosts[site][type][color]

      if ip
        host['ip'] = ip
        Kit.update_host(site, type, color, host)
      end

      Knife.upload_secret(host)
    end

    desc 'bootstrap SITE TYPE COLOR [IP]', 'run chef recipes on host'
    def bootstrap(site, type, color, ip = nil)
      host = Kit.hosts[site][type][color]

      knife = Knife.new site, type, host
      knife.bootstrap
    end

    desc 'ssh SITE TYPE COLOR', 'ssh to the host'
    def ssh(site, type, color, user = nil)
      host = Kit.hosts[site][type][color]
      user ||= host['user'] || 'ubuntu'
      use_ssh_key = (user == 'ubuntu')

      cmd = 'ssh'
      cmd += " -i #{host['ssh_key']}" if host['ssh_key'] && use_ssh_key
      cmd += " #{user}@#{host['ip']}"
      puts cmd
      exec cmd
    end


    desc 'cook SITE TYPE COLOR', 'run chef recipes on host'
    def cook(site, type, color)
      host = Kit.hosts[site][type][color]
      Kit.copy_node_config(site, type, host['ip'])
      exec "bundle exec knife solo cook ubuntu@#{host['ip']} -i ~/.ssh/app-ssh.pem"
    end

    desc 'deploy SITE TYPE COLOR', 'run capistrano deploy scripts'
    def deploy(site, type, color)
      server = Server.new site, type, color
      server.deploy
    end

    desc 'browse SITE TYPE COLOR', 'open browser to show host'
    def browse(site, type, color = :red)
      host = Kit.hosts[site][type][color]
      exec "open 'http://#{host['ip']}:8081'"
    end

    desc 'image SITE TYPE COLOR', 'make a bootable image of a running server'
    def image(site, type, color = 'red')
      host = Kit.hosts[site][type][color]
      image = Amazon.image(site, type, color, host)
      puts "Created image #{image}"
    end

    desc 'promote_image SITE TYPE IMAGE', 'configure all non-build instances to use new image'
    def promote_image(site, type, image)
      host_names = []
      Kit.hosts[site][type].each do |color, config|
        next if color == 'build'

        Kit.update_host(site, type, color, config.merge('image' => image))
        host_names << color
      end

      puts "Promoted image #{image} to be used by #{host_names.join(', ')}"
    end

    desc 'destroy SITE TYPE COLOR', 'delete the instance'
    def destroy(site, type, color)
      host = Kit.hosts[site][type][color]
      report "Deleting server #{instance_id}..." do
        if host['platform'] =~ /smartos/
          info = `kit list_instances smartos | grep #{site}-#{type}`
          puts "Are you sure you want to destroy #{info}?"
          return unless STDIN.gets =~ /y/i
          instance_id = info.split(/\s/).first
          SmartOS.delete_instance instance_id
        else
          info = `kit list_instances ec2 | grep #{host['ip']}`
          puts "Are you sure you want to destroy #{info}?"
          return unless STDIN.gets =~ /y/i
          instance_id = info.split(/\s/).first
          Amazon.delete_instance instance_id
        end
      end
    end

    #desc 'migrate HOST', 'migrate servers to use new statsd server'
    #def migrate(color = :red)
      ##report 'Migrating solr...' do
        ##`cd ~/stats; heroku run WEBSOLR_URL=http://#{host}:8080/solr rake sunspot:reindex[100,Resource]`
      ##end

      #STATSD_CLIENTS.each do |client|
        #report 'Configuring statsd clients' do
          #`heroku config:set WEBSOLR_URL=http://#{IPS[color.to_sym]}:8080/solr -a #{client}`
        #end
      #end

      #COLLECTD_CLIENTS.each do |client|
        #report 'Configuring collectd clients' do
          #`heroku config:set REDIS_HOST=#{IPS[color.to_sym]}:6379 -a #{client}`
        #end
      #end
    #end

    no_commands do
      def logger
        @logger ||= Logger.new(STDOUT)
      end
    end
  end
end
