# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "upnp/version"

Gem::Specification.new do |s|
  s.name        = "upnp"
  s.version     = UPnP::VERSION
  s.authors     = ["turboladen"]
  s.email       = ["steve.loveless@gmail.com"]
  s.homepage    = "http://github.com/turboladen/upnp"
  s.summary     = %q{Use me to build a UPnP app!}
  s.description = %q{upnp provides the tools you need to build an app that runs
in a UPnP environment.}

  s.rubyforge_project = "upnp"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.extra_rdoc_files = %w(History.rdoc README.rdoc)
  s.require_paths = ["lib"]

  s.required_ruby_version = Gem::Requirement.new(">=1.9.1")

  s.add_dependency('nori', '~>1.0.2')
  s.add_dependency('eventmachine', '>=1.0.0.beta.4')
  s.add_development_dependency('code_statistics', '>=0.2.13')
  s.add_development_dependency('cucumber', '>=1.0.0')
  s.add_development_dependency('metric_fu', '>=2.0.1')
  s.add_development_dependency('rspec', '>=2.6.0')
  s.add_development_dependency('simplecov', '>=0.4.2')
  s.add_development_dependency('yard', '>=0.6.0')
end
