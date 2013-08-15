task :deploy_app_exporter do
  host = hosts[site][type][color]['ip']
  root = "/home/app/exporter"

  set :user, "app"

  set :default_environment, {
    'RAILS_ENV' => "production",
    'DATABASE_URL' => 'postgres://vqwpemiqlgpgjr:vNC0dhw0el75v4Yugx_pzAsywK@ec2-54-243-193-133.compute-1.amazonaws.com:5432/d9easvipucphmu',
    'PATH' => "$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH",
    'CARRIER_WAVE_STORAGE' => 'fog',
    'AWS_ACCESS_KEY' => 'AKIAJM5ZKUWGZUH3SJGQ',
    'AWS_ACCESS_SECRET' => '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'
  }

  set :rails_env, "production"
  role :exporter, host

  bundle_flags = "--deployment --quiet --binstubs"
  run "cd #{root} && bundle install #{bundle_flags}"
  run "cd #{root} && rake export_and_package"
end
