require 'net/http'
require "yaml"
require 'json'

# Colorize from http://kpumuk.info/ruby-on-rails/colorizing-console-ruby-script-output/

def colorize(text, color_code)
  "#{color_code}#{text}\e[0m"
end

def hosts(type)
  @hosts ||= JSON.parse(File.read('config/hosts.json'))
  @hosts[type.to_s]
end

def red(text); colorize(text, "\e[31m"); end
def green(text); colorize(text, "\e[32m"); end

require "bundler/capistrano"
set :bundle_flags, "--deployment --quiet --binstubs"

set :default_environment, {
  'PATH' => "$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
}

require './config/boot'

before :vagrant, :default_config
before :production, :default_config
before :hou, :default_config

before 'bundle:install',    'deploy:symlink_shared'
after 'deploy:update_code', 'submodules:update'
after 'deploy:update_code', 'db:migrate'

before 'db:migrate',     'deploy:web:disable'
after 'deploy',          'deploy:web:enable'

after 'deploy',             'upstart:restart'
after 'deploy',             'deploy:cleanup'

set :use_sudo, false

## ssh options
ssh_options[:forward_agent] = true
default_run_options[:pty] = true

task :default_config do
  set :application, "inspirehq.com"
  set :user, "inspire"
  set :deploy_to, "/home/#{user}/#{user}" 
  default_environment['RAILS_ENV'] = "production"
  set :rails_env, "production"
end

task :vagrant do
  set :branch, "develop"

  role :app
  role :web
  role :db
  server '192.168.0.100', :app, :web, :db, primary: true
end

task :production do
  #set :branch, "master"
  set :branch, "develop"

  require 'json'
  role :app, *hosts(:app)
  role :web, *hosts(:web)
  role :db,  *hosts(:db), :primary => true
end

task :hou do
  set :branch, "master"

  require 'json'
  role :app, *hosts(:app_dev)
  role :web, *hosts(:web_dev)
  role :db,  *hosts(:db_dev), :primary => true
end

namespace :deploy do
  desc "Restart Application"
  task :restart, :roles => :app do
    run "touch #{current_release}/tmp/restart.txt"
    run 'restart inspire-mail_receiver'
  end

  task :symlink_shared do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
    run "ln -nfs #{shared_path}/config/mail.yml #{release_path}/config/mail.yml"
    run "ln -nfs #{shared_path}/config/amazon_s3.yml #{release_path}/config/amazon_s3.yml"
    run "ln -nfs #{shared_path}/bundle #{release_path}/vendor/bundle"
    run "ln -nfs #{shared_path}/sockets #{release_path}/tmp/sockets"
    run "ln -nfs #{shared_path}/pids #{release_path}/tmp/pids"
    run "ln -nfs #{shared_path}/.ruby-version #{release_path}/.ruby-version"
  end

  namespace :web do
    desc "This is to put up the maintenance page, and done right before migrating the database on a deploy."
    task :disable do
      run "ln -nfs #{current_release}/public/maintenance.html #{current_release}/public/site_down.html"
    end

    desc "This is to re-enable the site, and is done after deploy:ping, which starts a passenger instance"
    task :enable do
      run "rm #{current_release}/public/site_down.html"
    end
  end
end

task :scale do
  concurrency = ARGV.select { |a| a =~ /=/ }.join(',')

  unless concurrency.empty?
    run 'rm -f /home/inspire/.init/*'
    puts green("Setting concurrency to #{concurrency}")
    run 'stop inspire; echo "OK"'
    run "cd #{current_release} && bin/foreman export upstart-user -f Procfile.production -u inspire --concurrency='#{concurrency}' -d /home/inspire/inspire/current"
    run "cd #{current_release} && bin/foreman export monit-user -f Procfile.production -u inspire --concurrency='#{concurrency}' -d /home/inspire/inspire/current"
    run 'chmod 700 ~/.monitrc'
    run 'start inspire'
  end
end

namespace :upstart do
  desc "Restart upstart services"
  task :restart, :roles => :app do
    run "restart inspire"
    puts green("Upstart restarted the 'inspire processes.")
  end
end

task :fix_permissions do
  run "chmod 777 #{current_release}/public -R"
end

namespace :submodules do
  desc "install submodules"
  task :update, :roles => :app do
    run "cd #{release_path} && git submodule update --init"
  end
end

namespace :db do
  task :migrate do
    run "cd #{current_release} && bundle exec rake db:migrate"
  end
  desc "Pull Database"
  task :pull, :roles => :db do
    get "#{shared_path}/config/database.yml", "/tmp/database.yml"
    db_settings = YAML.load_file("/tmp/database.yml")
    database = db_settings["production"]["database"]
    username = db_settings["production"]["username"]
    password = db_settings["production"]["password"]
    host = db_settings["production"]["host"]

    filename = "#{database}-#{Time.now.strftime '%Y%m%d%H%M%S'}.dump"

    on_rollback {
      run "rm /tmp/#{filename}"
      run "rm /tmp/#{filename}.gz"
      run "rm /tmp/database.yml"
    }

    run "mysqldump -u#{username} -p'#{password}' -h#{host} #{database} > /tmp/#{filename}"
    run "gzip /tmp/#{filename}"
    get "/tmp/#{filename}.gz", "/tmp/#{filename}.gz"
    run "rm /tmp/#{filename}.gz"

    local_db_settings = YAML.load_file("config/database.yml")
    local_database = local_db_settings["development"]["database"]

    system "gunzip /tmp/#{filename}.gz"
    system "mysqladmin -f -uroot drop #{local_database}"
    system "mysqladmin -f -uroot create #{local_database}"
    system "mysql -uroot #{local_database} < /tmp/#{filename}"
    system "rm /tmp/#{filename}"
    system "rm /tmp/database.yml"
  end
end

namespace :dns do
  task :update do
    yml = YAML::load(`knife solo data bag show inspire dns --secret-file ~/.knife.secret`)
    email, token = yml['dnsimple'].values

    ip = `knife ec2 server list | awk '{print $3;}' | tail -n 1`.chomp
    dns = JSON.parse(`curl -H "Accept: application/json" -H "X-DNSimple-Token: #{email}:#{token}" https://dnsimple.com/domains/41489/records`)

    dns.each do |record|
      record = record['record']
      if record['record_type'] == 'A'
        puts `curl -H "Accept: application/json" -H "Content-Type: application/json" -H "X-DNSimple-Token: #{email}:#{token}" -i -X PUT https://dnsimple.com/domains/#{record['domain_id']}/records/#{record['id']} -d '{"record":{"content":"#{ip}"}}'`
      end
    end
  end
end

# uri is required for tinder
require 'uri'
