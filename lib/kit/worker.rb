require 'sidekiq'
require 'kit/helpers'

module Kit
  class Worker
    include Sidekiq::Worker
    include Kit::Helpers

    attr_accessor :log

    def log
      @log ||= ''
    end

    def perform(exe, command, site, type, extra = nil)
      shellout "bin/#{exe} #{command} #{site} #{type} #{extra}"
    end
  end
end
