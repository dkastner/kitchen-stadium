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
    def launch(site, type, color = 'red')
      server = Server.new site, type, color

      puts 'ALLEZ CUISINE!!!'
      if RUBY_PLATFORM =~ /darwin/ && Random.rand(100) > 90
        `say -vAlex ah-lay cuisine!` 
      end

      if options.create
        logger.info "Creating instance #{server.id}"
        server.create_instance
        server.bootstrap
      end

      if options.deploy
        logger.info "Waiting for instance #{server.id} to become available"
        server.wait
        logger.info "Deploying instance #{server.id}"
        success = server.deploy

        if success
          campfire.speak ":tada: Allez cuisine! Chairman launched #{server.id} :tada:"
          campfire.play 'tada'
        else
          campfire.speak "FAILURE Chairman tried to launch #{server.id}"
          campfire.play 'drama'
          campfire.speak server.log
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
        logger.info "Creating instance #{server.id}"
        server.create_instance
      end

      if options.bootstrap
        server.bootstrap
      end

      if options.cook
        logger.info "Cooking instance #{server.id}"
        server.cook
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
    end
  end
end
