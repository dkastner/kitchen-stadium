require 'json'
require 'thor'

require 'kit/amazon'
require 'kit/helpers'
require 'kit/knife'
require 'kit/smart_os'

module Kit
  class CLI < Thor
    include Kit::Helpers

    attr_accessor :host, :instance_id, :execution_mode

    AMIS = {
      u1204_64_us_east: 'ami-fd20ad94',
      inspire_www_latest: 'ami-328a165b'
    }

    HOSTS = JSON.parse(
      File.read(File.expand_path('../../../config/hosts.json', __FILE__)))

    APP_SOLR_CLIENTS = %w{app-admin app-catalog}
    STATSD_CLIENTS = %w{stats}
    COLLECTD_CLIENTS = %w{app-solr}

    desc 'list', 'list all hosts'
    def list
      require 'terminal-table'
      items = []
      items << ['Site', 'Type', 'Color', 'IP']
      HOSTS.each do |site, types|
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
      host = HOSTS[site][type][color]
      platform = host['platform'].to_sym
      instance_id = nil

      report 'Creating instance...' do
        case platform
        when :smartos_smartmachine then
          instance_id = SmartOS::SmartMachine.create_instance site, type, host
        when :smartos_ubuntu then
          instance_id = SmartOS::Ubuntu.create_instance site, type, host
        else
          image = AMIS[platform]
          instance_id = Amazon::Ubuntu.create_instance site, type, host, image
        end
      end

      puts "Created host #{site}-#{type}-#{color}@#{host['ip']} id #{instance_id}"

      knife = Knife.new host
      knife.upload_secret
      knife.bootstrap
    end

    desc 'list_instances PLATFORM', 'list running instances'
    def list_instances(platform)
      if platform =~ /amazon/ || platform =~ /ec2/
        Amazon.list_instances
      else
        SmartOS.list_instances
      end
    end

    desc 'upload_knife_secret SITE TYPE COLOR', 'upload ~/.ssh/knife.pem to server'
    def upload_knife_secret(site, type, color)
      host = HOSTS[site][type][color]
      Knife.upload_secret(host)
    end

    desc 'cook HOST', 'run chef recipes on host'
    def cook(color = :red)
      report "Cooking..." do
        sh "bundle exec knife solo cook ubuntu@#{IPS[color.to_sym]} -i ~/.ssh/stats.pem"
      end
    end

    desc 'browse HOST', 'open browser to show host'
    def browse(site, type, color = :red)
      host = HOSTS[site][type][color]
      exec "open 'http://#{host['ip']}:8081'"
    end

    desc 'destroy PLATFORM INSTANCE', 'delete the instance'
    def destroy(platform, instance_id)
      report "Deleting server #{instance_id}..." do
        if platform =~ /smartos/
          SmartOS.delete_instance instance_id
        else
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
  end
end
