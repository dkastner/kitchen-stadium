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

    def sh(cmd, fail = true)
      if execution_mode == :popen
        out = ''
        IO.popen(cmd) do |io|
          data = io.gets
          puts data
          out += data.to_s
        end
        out
      else
        exec cmd
      end
    end

    def wait(host)
      report "Waiting for server #{host}", 'ready!' do
        waiting = true
        while waiting
          status = ''
          IO.popen(%{ssh -y -i ~/.ssh/inspire-www.pem -o "ConnectTimeout=5" -o "StrictHostKeyChecking=false" ubuntu@#{host} "echo OK"}) do |ssh|
            status += ssh.gets.to_s
          end
          waiting = (status !~ /OK/)
          dot
        end
      end
    end
  end
end
