require 'json'
require 'thor'

require 'kit/amazon'
require 'kit/helpers'
require 'kit/knife'
require 'kit/server'
require 'kit/server_list'
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
      ServerList.formatted :all
    end

    desc 'running', 'list running instances'
    def running
      ServerList.formatted :running
    end

    desc 'build SITE TYPE [COLOR]',
      'build a new instance from scratch, e.g. `app solr` or `app solr red`'
    def create_instance(site, type, color = nil)
      server = Server.from_scratch logger, site, type, color
      logger.info "Created host #{site}-#{type}-#{color}@#{server.ip} (#{server.instance_id})"
    end

    desc 'launch SITE TYPE [COLOR]',
      'launch a new instance from an image, e.g. `app solr` or `app solr red`'
    def create_instance(site, type, color = nil)
      server = Server.launch site, type, color
      logger.info "Created host #{site}-#{type}-#{server.color}@#{server.ip} (#{server.instance_id})"
    end

    desc 'bootstrap SITE TYPE COLOR [IP]', 'run chef recipes on host'
    def bootstrap(site, type, color, ip = nil)
      server = choose_server(site, type, color, 'bootstrap')
      server.bootstrap_chef
    end

    desc 'ssh SITE TYPE COLOR', 'ssh to the host'
    def ssh(site, type, color, user = nil)
      server = choose_server(site, type, color, 'connect to')
      use_ssh_key = (server.user == 'ubuntu')

      cmd = 'ssh'
      cmd += %{ -o "StrictHostKeyChecking=false"}
      cmd += " -i #{server.ssh_key}" if server.ssh_key && use_ssh_key
      cmd += " #{server.user}@#{server.ip}"
      puts cmd
      exec cmd
    end


    desc 'cook SITE TYPE COLOR', 'run chef recipes on host'
    def cook(site, type, color)
      server = choose_server(site, type, color, 'cook')
      server.cook
    end

    desc 'deploy SITE TYPE COLOR', 'run capistrano deploy scripts'
    def deploy(site, type, color)
      servers = choose_server(site, type, color, 'image', multiple: true)
      servers.map(&:deploy)
    end

    desc 'browse SITE TYPE COLOR', 'open browser to show host'
    def browse(site, type, color = :red)
      server = Server.new site, type, color
      exec "open 'http://#{server.ip}:8081'"
    end

    desc 'image SITE TYPE COLOR', 'make a bootable image of a running server'
    def image(site, type, color = 'red')
      servers = choose_server(site, type, color, 'image', multiple: true)
      servers.each do |server|
        server.create_image!
        puts "Created image #{server.image} of #{server.id}"
      end
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
    method_option :override, type: :boolean, default: false, aliases: '-y'
    def destroy(site, type, color)
      servers = choose_server(site, type, color, 'destroy',
                              confirm: true, multiple: true,
                              override: options[:override])
      servers.each do |server|
        report "Deleting server #{server.id}..." do
          server.destroy!
        end
      end
    end


    no_commands do
      def logger
        @logger ||= Logger.new(STDOUT)
      end

      def choose_server(site, type, color, action, options = {})
        choices = ServerList.find_by_name site, type, color

        result = if choices.length > 1
          puts "Please choose a host to #{action}:"
          ServerList.formatted(choices, numbered: true)
          choice = STDIN.gets 
          if choice =~ /a/ && options[:multiple]
            choices
          elsif choice =~ /\d/ && options[:multiple]
            choice.split(/\s+/).map do |c|
              choices[c.to_i]
            end
          else
            choices[choice.to_i]
          end
        else
          server = choices.first
          if options[:confirm] && !options[:override]
            puts "Are you sure you want to #{action} #{server.id}?"
            return unless STDIN.gets =~ /y/i
          end
          server
        end

        options[:multiple] ? Array(result) : result
      end
    end
  end
end
