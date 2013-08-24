#!/usr/bin/env ruby

require 'kit/cli'
require 'json'

module Kit
  HOSTS_PATH = File.expand_path('../../config/hosts.json', __FILE__)
  NODES_PATH = File.expand_path('../../nodes', __FILE__)

  def self.update_host(site, type, color, data)
    hosts[site][type][color] = data
    File.open(HOSTS_PATH, 'w') { |f| f.puts JSON.pretty_generate(hosts) }
  end

  def self.hosts
    @hosts ||= JSON.parse(File.read(HOSTS_PATH))
  end

  def self.copy_node_config(site, type, ip, method = 'build')
    source = File.join NODES_PATH, "#{site}-#{type}-#{method}.json"
    if File.exists?(source)
      FileUtils.cp source, File.join(NODES_PATH, "#{ip}.json")
    end
  end
end
