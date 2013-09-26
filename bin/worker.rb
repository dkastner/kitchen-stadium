#!/usr/bin/env ruby
require 'bundler/setup'

require 'dotenv'
Dotenv.load

$:.unshift File.expand_path('../../lib', __FILE__)
require 'kit/worker'

Sidekiq.configure_server do |config|
  config.redis = {
    namespace: 'kitchen-stadium', url: ENV['REDIS_HOST']
  }
end
