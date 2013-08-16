task :deploy_app_importer do
  host = hosts[site][type][color]['ip']

  set :user, "app"

  set :default_environment, {
    'RAILS_ENV' => "production",
    'DATABASE_URL' => 'postgres://vqwpemiqlgpgjr:vNC0dhw0el75v4Yugx_pzAsywK@ec2-54-243-193-133.compute-1.amazonaws.com:5432/d9easvipucphmu',
    'PATH' => "$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
  }

  role :importer, host

  root = "/home/app/importer"

  bundle_flags = "--deployment --quiet --binstubs"
  run "cd #{root} && bundle install #{bundle_flags}"
  run "cd #{root} && rake import"
end
before :deploy_app_importer, :config
