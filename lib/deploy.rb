#!/usr/bin/env ruby
require 'thor'

require 'deploy/helpers'

class DeployCLI < Thor
  include Deploy::Helpers

  attr_accessor :host, :instance_id, :execution_mode

  AMIS = {
    u1204_64_us_east: 'ami-fd20ad94',
    latest: 'ami-328a165b'
  }

  IPS = {
    red: '54.225.206.236',
    blue: '',
  }

  STATSD_CLIENTS = %w{stats}
  COLLECTD_CLIENTS = %w{app-solr}

  desc 'create_instance COLOR AMI', 'create a new ec2 instance, optional AMI param'
  def create_instance(color = :red, ami = :u1204_64_us_east)
    data = nil
    report 'Creating instance...' do
      data = sh("bundle exec knife ec2 server create -f t1.micro -I #{AMIS[ami.to_sym]} -Z us-east-1c -S stats -G graphiti,graphite,statsd,sshd -N stats --ssh-user=ubuntu -i ~/.ssh/stats.pem --elastic-ip #{IPS[color.to_sym]}")
    end
    self.instance_id = data.split(/:/).last.chomp
    self.color = color
    puts "Created host #{IPS[color.to_sym]}"
  end

  desc 'upload_knife_secret COLOR', 'upload ~/.knife.secret to servers'
  def upload_knife_secret(color = :red)
    report "Copying encrypted data bag secret..." do
      puts `scp -i ~/.ssh/stats.pem ~/.knife.secret ubuntu@#{IPS[color.to_sym]}:/tmp/encrypted_data_bag_secret`
    end
  end

  desc 'cook HOST', 'run chef recipes on host'
  def cook(color = :red)
    report "Cooking..." do
      sh "bundle exec knife solo cook ubuntu@#{IPS[color.to_sym]} -i ~/.ssh/stats.pem"
    end
  end

  desc 'washup HOST', 'remove chef from host'
  def washup(color = :red)
    report "Washing up..." do
      `bundle exec knife wash_up ubuntu@#{IPS[color.to_sym]} -i ~/.ssh/stats.pem`
    end
  end

  desc 'browse HOST', 'open browser to show host'
  def browse(color = :red)
    exec "open 'http://#{IPS[color.to_sym]}:8081'"
  end

  desc 'full HOST', 'run a full deploy'
  def full(specified_color = :red)
    self.execution_mode = :popen
    self.host = specified_host

    create_instance unless specified_host

    Signal.trap("INT") do
      puts "Shutting down..."
      destroy
      exit
    end
    Signal.trap("KILL") do
      puts "Shutting down..."
      destroy
      exit
    end

    begin
      upload_knife_secret

      cook
      washup

      browse
    rescue => e
      puts %{ERROR: #{e} #{e.backtrace.join("\n")}}
      destroy
    end
  end

  desc 'destroy HOST', 'delete the ec2 instance'
  def destroy(instance_id)
    report "Deleting server #{instance_id}..." do
      `knife ec2 server delete #{instance_id} -y`
    end
  end

  #desc 'migrate HOST', 'migrate servers to use new statsd server'
  #def migrate(color = :red)
    ##report 'Migrating solr...' do
      ##`cd ~/stats; heroku run WEBSOLR_URL=http://#{host}:8080/solr rake sunspot:reindex[100,Resource]`
    ##end

    #STATSD_CLIENTS.each do |client|
      #report 'Configuring statsd clients' do
        #`heroku config:set WEBSOLR_URL=http://#{IPS[color.to_sym]}:8080/solr -a #{client}`
      #end
    #end

    #COLLECTD_CLIENTS.each do |client|
      #report 'Configuring collectd clients' do
        #`heroku config:set REDIS_HOST=#{IPS[color.to_sym]}:6379 -a #{client}`
      #end
    #end
  #end
end
