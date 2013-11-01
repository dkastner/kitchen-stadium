module Kit
  module Helpers
    def report(txt, done = 'done!')
      print txt
      STDOUT.flush
      yield if block_given?
      puts done
    end

    def dot
      print '.'
      STDOUT.flush
    end

    def sh(cmd)
      out = ''
      IO.popen(cmd) do |io|
        data = io.gets
        puts data
        out += data.to_s
      end
      out
    end

    def logger
      @logger ||= Logger.new(STDOUT)
    end

    def shellout(cmd)
      result = nil
      IO.popen cmd do |io|
        while line = io.gets
          self.log += line if respond_to?(:log)
          logger.info line
        end
        io.close
        result = $?.to_i
      end
      result == 0
    end
  end
end
