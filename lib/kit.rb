require 'json'

module Kit
  extend self

  HOSTS_PATH = File.expand_path('../../config/hosts.json', __FILE__)
  NODES_PATH = File.expand_path('../../nodes', __FILE__)
  COLORS = %w{red orange yellow green blue purple brown white black}

  def update_host(site, type, color, data)
    hosts[site][type][color] = data
    File.open(HOSTS_PATH, 'w') { |f| f.puts JSON.pretty_generate(hosts) }
  end

  def hosts
    @hosts ||= JSON.parse(File.read(HOSTS_PATH))
  end

  def default_cloud
    @default_cloud ||= ENV['DEFAULT_CLOUD'] ? 
      ENV['DEFAULT_CLOUD'].to_sym :
      :amazon
  end
  def default_cloud=(val)
    @default_cloud = val
  end

  def copy_node_config(site, type, ip, method = 'build')
    source = File.join NODES_PATH, "#{site}-#{type}-#{method}.json"
    if File.exists?(source)
      FileUtils.cp source, File.join(NODES_PATH, "#{ip}.json")
    end
  end
end
