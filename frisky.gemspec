# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'frisky/version'

Gem::Specification.new do |s|
  s.name        = 'frisky'
  s.version     = Frisky::VERSION
  s.author      = 'Jon Frisby'
  s.email       = 'jfrisby@mrjoy.com'
  s.homepage    = 'http://github.com/MrJoy/frisky'
  s.summary     = 'Use me to build a UPnP app!'
  s.description = %q{frisky provides the tools you need to build an app that runs
in a UPnP environment.}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.extra_rdoc_files = %w(History.md README.md LICENSE.md)
  s.require_paths = ['lib']
  s.required_ruby_version = Gem::Requirement.new('>=1.9.1')

  s.add_dependency 'eventmachine', '>=1.0.0'
  s.add_dependency 'em-http-request', '>=1.0.2'
  s.add_dependency 'em-synchrony'
  s.add_dependency 'nori', '>=2.0.2'
  s.add_dependency 'log_switch', '~>1.0.0'
  s.add_dependency 'savon', '~>2.0'
end
