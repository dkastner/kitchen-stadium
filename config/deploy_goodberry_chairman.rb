task :deploy_app_chairman do
  host = hosts[site][type][color]['ip']
  root = "/home/app/kitchen-stadium"

  set :user, "app"

  set :default_environment, {
    'PATH' => "$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH",
    'AWS_ACCESS_KEY' => 'AKIAJM5ZKUWGZUH3SJGQ',
    'AWS_ACCESS_SECRET' => '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'
  }

  set :rails_env, "production"
  role :chairman, host

  run "cd #{root} && git pull origin master"

  bundle_flags = "--deployment --quiet --binstubs"
  run "cd #{root} && bundle install #{bundle_flags}"
end
