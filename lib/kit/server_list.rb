require 'kit/cloud/amazon'
require 'kit/cloud/vagrant'
require 'kit/server'

module Kit
  class ServerList < Array
    def self.all
      list = new(Kit::Cloud::Amazon.server_list) +
        new(Kit::Cloud::Vagrant.server_list)

      server_list = new
      list.each do |server|
        server_list << server
      end
      server_list
    end

    def self.find_by_name(site, type, color)
      needle = Server.new site, type, color
      running.find_all { |s| s.instance_name == needle.instance_name }
    end

    def self.running
      all.running.sort { |a, b| b.created_at.to_i <=> a.created_at.to_i }
    end

    def self.formatted(method_or_list, options = {})
      require 'terminal-table'
      items = []

      list = if method_or_list.is_a?(Symbol)
               send(method_or_list)
             else
               method_or_list
             end

      number = 0
      items += list.map do |server|
        item = server.status_line
        item.unshift number if options[:numbered]
        number += 1
        item
      end

      headings = %w{Site Type Color Cloud Status IP ID Uptime}
      headings.unshift 'Selection' if options[:numbered]
      puts Terminal::Table.new(rows: items, headings: headings)
    end

    def self.find_by_ip(ip)
      all.find_by_ip(ip)
    end

    def self.running_colors(site, type)
      running.find_all { |s| s.site == site && s.type == type }.
        map(&:color)
    end

    def running
      find_all { |s| s.running? }
    end

    def find_by_ip(ip)
      find { |s| s.ip == ip }
    end
  end
end
