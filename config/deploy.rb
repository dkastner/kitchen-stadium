require 'net/http'
require "yaml"
require 'json'

# Colorize from http://kpumuk.info/ruby-on-rails/colorizing-console-ruby-script-output/

def colorize(text, color_code)
  "#{color_code}#{text}\e[0m"
end
#def red(text); colorize(text, "\e[31m"); end
#def green(text); colorize(text, "\e[32m"); end

load File.expand_path('../deploy_app_importer.rb', __FILE__)
