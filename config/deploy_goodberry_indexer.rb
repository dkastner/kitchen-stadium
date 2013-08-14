require 'net/http'
require "yaml"
require 'json'

set :default_environment, {
  'PATH' => "$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
}

before :production, :default_config
before :hou, :default_config

set :use_sudo, false

## ssh options
ssh_options[:forward_agent] = true
default_run_options[:pty] = true

hosts = JSON.parse(File.read('config/hosts.json'))

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

task :config do
  host = hosts[site][type][color]['ip']

  set :user, "app"

  set :default_environment, {
    'RAILS_ENV' => "production",
    'DATABASE_URL' => 'postgres://vqwpemiqlgpgjr:vNC0dhw0el75v4Yugx_pzAsywK@ec2-54-243-193-133.compute-1.amazonaws.com:5432/d9easvipucphmu',
    'PATH' => "$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
  }

  set :rails_env, "production"
  role :importer, host
end

root = "/home/app/catalog"

task :deploy_app_importer do
  bundle_flags = "--deployment --quiet --binstubs"
  run "cd #{root} && bundle install #{bundle_flags}"
  run "cd #{root} && rake import"
end
before :deploy_app_importer, :config
