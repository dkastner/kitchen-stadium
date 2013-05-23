#!/usr/bin/env ruby

require 'kit/cli'
require 'json'

module Kit
  HOSTS_PATH = File.expand_path('../../config/hosts.json', __FILE__)

  def self.update_host(site, type, color, data)
    hosts[site][type][color] = data
    File.open(HOSTS_PATH, 'w') { |f| f.puts hosts.to_json }
  end

  def self.hosts
    @hosts ||= JSON.parse(File.read(HOSTS_PATH))
  end
end
