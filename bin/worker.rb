#!/usr/bin/env ruby
require 'bundler/setup'

require 'dotenv'
Dotenv.load

redis_url = ENV['REDIS_HOST'].to_s =~ /^redis:/ ?
  ENV['REDIS_HOST'] : "redis://#{ENV['REDIS_HOST']}"

Sidekiq.configure_server do |config|
  config.redis = { namespace: 'kitchen-stadium', url: redis_url }
end

$:.unshift File.expand_path('../../lib', __FILE__)
require 'kit/worker'
