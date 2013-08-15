module Kit
  module Helpers
    def report(txt, done = 'done!')
      print txt
      STDOUT.flush
      yield
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
  end
end
