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
ssh_options[:verbose] = :debug
ssh_options[:user] = 'ubuntu'
default_run_options[:pty] = true

set :hosts, JSON.parse(File.read('config/hosts.json'))

hosts.each do |site, type_data|
  task site do
    set :site, site
  end

  type_data.each do |type, color_data|
    task type do
      set :type, type
    end

    color_data.each do |color, host_data|
      task color do
        set :color, color
      end
    end
  end
end


task :process, role: :indexer do
  $:.unshift File.expand_path('../../lib', __FILE__)
  require 'kit/server_list'
  servers = Kit::ServerList.find_by_name site, type, color
  servers.each do |server|
    role server.type.to_sym, server.ip if server.ip
  end
  raise "No servers named '#{site}-#{type}-#{color}' running" if servers.empty?

  case type
  when 'indexer'
    run "cd $HOME/indexer && rake index"
  when 'importer'
    run "cd $HOME/import && rake import"
  when 'deal-mailer'
    run "cd $HOME/deal-mailer && rake deals:fetch"
    run "cd $HOME/importer && rake deal_resources"
    run "cd $HOME/deal-mailer && rake deals:activate"
  end
end
