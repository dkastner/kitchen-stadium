require 'bundler'
Bundler.setup

require 'dotenv'
Dotenv.load

require 'net/http'
require "yaml"
require 'json'

# Colorize from http://kpumuk.info/ruby-on-rails/colorizing-console-ruby-script-output/

def colorize(text, color_code)
  "#{color_code}#{text}\e[0m"
end
#def red(text); colorize(text, "\e[31m"); end
#def green(text); colorize(text, "\e[32m"); end

set :default_environment, {
  'PATH' => "$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
}

set :use_sudo, false

## ssh options
ssh_options[:forward_agent] = true
ssh_options[:keys] = [
  File.join(ENV['HOME'], '.ssh', 'app-ssh.pem')]
#ssh_options[:verbose] = :debug
ssh_options[:user] = 'ubuntu'
default_run_options[:pty] = true

$:.unshift File.expand_path('../../lib', __FILE__)
require 'kit/server_list'

running_servers = Kit::ServerList.running

running_servers.each do |server|
  task server.site do
    set :site, server.site
  end
  task server.type do
    set :type, server.type
  end
  if server.color
    task server.color do
      set :color, server.color
    end
  end
end


task :process, role: :default do
  case type
  when 'indexer'
    run "cd $HOME/indexer && rake index"
  when 'fetcher'
    run "cd $HOME/fetcher && rake fetch"
  end
end

task :set_roles do
  servers = Kit::ServerList.find_by_name site, type, color
  servers.each do |server|
    role server.type.to_sym, server.ip if server.ip
  end
  raise "No servers named '#{site}-#{type}-#{color}' running" if servers.empty?
end

before :invoke, :set_roles
before :process, :set_roles
