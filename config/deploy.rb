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

load File.expand_path('../deploy_app_dev.rb', __FILE__)
load File.expand_path('../deploy_app_importer.rb', __FILE__)
load File.expand_path('../deploy_app_exporter.rb', __FILE__)
load File.expand_path('../deploy_app_deal-mailer.rb', __FILE__)
