task :deploy_app_deal_mailer do
  host = hosts[site][type][color]['ip']
  mailer_root = "/home/app/deal-mailer"
  importer_root = "/home/app/importer"

  set :user, "app"

  set :default_environment, {
    'RAILS_ENV' => "production",
    'DATABASE_URL' => 'postgres://vqwpemiqlgpgjr:vNC0dhw0el75v4Yugx_pzAsywK@ec2-54-243-193-133.compute-1.amazonaws.com:5432/d9easvipucphmu',
    'PATH' => "$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH",
    'CARRIER_WAVE_STORAGE' => 'fog',
    'AWS_ACCESS_KEY' => 'AKIAJM5ZKUWGZUH3SJGQ',
    'AWS_ACCESS_SECRET' => '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',
    'GOOGLE_USERNAME' => 'derek@lan.io',
    'GOOGLE_PASSWORD' => 'companycompany'
  }

  set :rails_env, "production"
  role :exporter, host

  run "cd #{mailer_root} && git pull origin master"
  run "cd #{importer_root} && git pull origin master"

  bundle_flags = "--deployment --quiet --binstubs"
  run "cd #{mailer_root} && bundle install #{bundle_flags}"
  run "cd #{importer_root} && bundle install #{bundle_flags}"

  run "cd #{mailer_root} && rake deals:fetch"
  run "cd #{importer_root} && rake deal_resources"
  run "cd #{mailer_root} && rake deals:mail"
end
