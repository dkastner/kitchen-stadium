# -*- encoding: utf-8 -*-
Gem::Specification.new do |gem|
  gem.name          = "kitchen-stadium"
  gem.version       = '1.0.0'
  gem.authors       = ["Derek Kastner"]
  gem.email         = ["dkastner@gmail.com"]
  gem.description   = %q{Kitchen Stadium}
  gem.summary       = %q{Manage servers}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'capistrano'
  gem.add_dependency 'dotenv'
  gem.add_dependency 'fog'
  gem.add_dependency 'heroku'
  gem.add_dependency 'librarian'
  #gem.add_dependency 'ruby-libvirt'
  gem.add_dependency 'knife-ec2'
  gem.add_dependency 'knife-solo'
  gem.add_dependency 'knife-solo_data_bag'
  gem.add_dependency 'sidekiq'
  gem.add_dependency 'terminal-table'
  gem.add_dependency 'thor'
  gem.add_dependency 'tinder'
end
