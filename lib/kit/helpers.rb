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

    def wait(host)
      report "Waiting for server #{host['ip']}", 'ready!' do
        waiting = true
        while waiting
          status = ''
          cmd = "ssh -y"
          cmd += " -i #{host['ssh_key']}" if host['ssh_key']
          cmd += %{ -o "ConnectTimeout=5" -o "StrictHostKeyChecking=false" #{host['user']}@#{host['ip']} "echo OK"}
          IO.popen(cmd) do |ssh|
            status += ssh.gets.to_s
          end
          waiting = (status !~ /OK/)
          dot
        end
      end
    end
  end
end
