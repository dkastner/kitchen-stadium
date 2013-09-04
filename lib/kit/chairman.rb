require 'logger'
require 'thor'
require 'tinder'

require 'kit/server'

module Kit
  class Chairman < Thor
    desc 'launch', 'SITE TYPE [COLOR]'
    method_option :create, :type => :boolean, :default => true
    method_option :deploy, :type => :boolean, :default => true
    method_option :destroy, :type => :boolean, :default => true
    def launch(site, type, color = nil)
      server = ServerList.find_by_name(site, type, color).first

      puts 'ALLEZ CUISINE!!!'
      if RUBY_PLATFORM =~ /darwin/ && Random.rand(100) > 90
        `say -vAlex ah-lay cuisine!` 
      end

      if options.create
        logger.info "Creating instance #{site}-#{type}"
        server = Server.launch site, type, color
        result = server.bootstrap_chef(false)
        failout server, "Failed to bootstrap #{server.id}", options unless result
      end

      if options.deploy
        logger.info "Deploying instance #{server.id}"
        success = server.deploy

        if success
          campfire.speak ":tada: Allez cuisine! Chairman launched #{server.id} :tada:"
          campfire.play 'tada'
        else
          failout server, "Deploy was unsuccessful", options
        end
      end

      if options.destroy
        logger.info "Destroying instance #{server.id}"
        server.destroy!
      end
    end
    
    desc 'build', 'SITE TYPE'
    method_option :create, :type => :boolean, :default => true
    method_option :bootstrap, :type => :boolean, :default => true
    method_option :cook, :type => :boolean, :default => true
    method_option :image, :type => :boolean, :default => true
    method_option :destroy, :type => :boolean, :default => true
    def build(site, type)
      server = Server.new site, type, 'build'

      if options.create
        logger.info "Creating instance #{site}-#{type}"
        server = Server.from_scratch(site, type, 'build')
      end

      if options.bootstrap
        server.bootstrap_chef
      end

      if options.image
        logger.info "Creating image of instance #{server.id}"
        server.create_image!
        puts "Creating image #{server.image}"
      end

      if options.destroy
        logger.info "Destroying instance #{server.id}"
        server.destroy!
      end
    end

    desc 'exec', 'SITE TYPE COMMAND'
    method_option :destroy, :type => :boolean, :default => false
    def exec(site, type, command)
      logger.info "Creating instance #{site}-#{type}"
      server = Server.launch site, type, nil
      result = server.bootstrap_chef(false)
      failout server, "Failed to bootstrap #{server.id}", options unless result

      logger.info "Deploying instance #{server.id}"
      success = server.run command

      if success
        logger.info "Command was unsuccessful"
      else
        fail "Command failed"
      end

      if options.destroy
        logger.info "Destroying instance #{server.id}"
        server.destroy!
      end
    end

    no_commands do
      def logger
        @logger ||= Logger.new(STDOUT)
      end

      def campfire
        return @campfire unless @campfire.nil?

        lobby = Tinder::Campfire.new 'company',
          :token => 'TOKEN'

        @campfire = lobby.rooms.first
      end

      def failout(server, message, options)
        campfire.speak "FAILURE Chairman tried to launch #{server.id}"
        campfire.play 'drama'
        campfire.speak server.log
        server.destroy! if options.destroy
        raise message
      end
    end
  end
end
