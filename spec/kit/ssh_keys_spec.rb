require 'spec_helper'
require 'kit/ssh_keys'

describe Kit::SSHKeys do
  describe '#path' do
    it 'uses an ENV-defined path' do
      ENV['OUR_THING_KEY_PATH'] = '/our/thing'

      ssh = Kit::SSHKeys.new 'OUR_THING'
      ssh.path.should == '/our/thing'
    end
    it 'uses a temporary file containing ENV data if available' do
      ENV['MY_THING_KEY'] = 'cosanostra'

      ssh = Kit::SSHKeys.new 'MY_THING'
      ssh.path.should =~ /temp-key/
      File.read(ssh.path).should == 'cosanostra'
    end
    it 'uses a default path when no ENV data is available' do
      ENV['MY_THING_KEY'] = nil
      ENV['MY_THING_KEY_PATH'] = nil

      ssh = Kit::SSHKeys.new 'MY_THING'
      ssh.path.should =~ /\.ssh\/kitchen-stadium-my-thing.key/
    end
  end
end

