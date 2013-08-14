require 'net/http'
require "yaml"

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

task :deploy_app_dev do
  apps = %w{app-accounts app-admin app-catalog
            app-checkout app-deals}
  libs = %w{app-assets app-commerce app-dealership
            app-resources}

  bundle_flags = "--deployment --quiet --binstubs"

  (apps + libs).each do |repo|
    dir = repo.split(/-/).last
    path = File.join('/home/app', dir)
    run "cd #{path} && bundle install #{bundle_flags}"
  end
end
before :deploy_app_importer, :config
