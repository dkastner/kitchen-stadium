require 'sidekiq'
require 'kit/helpers'

require 'kit/worker/export'
require 'kit/worker/import'

module Kit
  class Worker
    class ExecutionFailed < StandardError; end

    include Sidekiq::Worker
    include Kit::Helpers

    attr_accessor :log

    def log
      @log ||= ''
    end

    def perform(exe, *extra)
      bin = exe == 'kit' ? 'bin/kit' : 'bin/chairman'
      unless shellout "#{bin} #{extra.join(' ')}"
        raise ExecutionFailed
      end
    end
  end
end
