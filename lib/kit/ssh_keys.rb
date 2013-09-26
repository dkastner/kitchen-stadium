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

    def temp_path
      if @temp_path && File.exist?(@temp_path)
        @temp_path
      else
        file = Tempfile.new 'temp-key'
        file.write env
        file.close
        file.path
      end
    end

    def default_path
      "#{ENV['HOME']}/.ssh/kitchen-stadium-#{friendly_name}.key"
    end
  end
end
