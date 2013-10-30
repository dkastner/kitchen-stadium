require 'tempfile'

module Kit
  class SSHKeys
    def self.aws_ssh_public
      @aws_ssh_public ||= new('AWS_SSH_PUBLIC')
    end
    def self.aws_ssh_private
      @aws_ssh_private ||= new('AWS_SSH_PRIVATE')
    end
    def self.knife_secret
      @aws_ssh_private ||= new('KNIFE_SECRET')
    end

    def self.with_keys(*key_names, &blk)
      keys = key_names.map { |name| new(name) }

      paths = keys.map(&:path)

      result = blk.call *paths

      keys.map(&:unlink_temp_file)

      result
    end

    def self.with_key_contents(*key_names, &blk)
      keys = key_names.map { |name| new(name) }

      contents = keys.map(&:content)

      result = blk.call *contents

      keys.map(&:unlink_temp_file)

      result
    end

    attr_accessor :name

    def initialize(name)
      self.name = name
    end

    def friendly_name
      name.downcase.gsub('_', '-')
    end

    def env
      ENV["#{name}_KEY"]
    end
    def path_env
      ENV["#{name}_KEY_PATH"]
    end

    def path
      if path_env
        path_env
      elsif env
        temp_path
      else
        default_path
      end
    end

    def content
      File.read path
    end

    def temp_path
      temp_file.path
    end

    def temp_file
      return @temp_file if @temp_file && File.exist?(@temp_file)

      file = Tempfile.new 'temp-key'
      file.write env
      file.close
      @temp_path = file
    end

    def default_path
      "#{ENV['HOME']}/.ssh/kitchen-stadium-#{friendly_name}.key"
    end

    def unlink_temp_file
      if path_env.nil? && env
        key.temp_file.unlink
      end
    end
  end
end
