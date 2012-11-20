# -*- encoding: utf-8 -*-  
$:.push File.expand_path("../lib", __FILE__)  
require "modelist/version" 

Gem::Specification.new do |s|
  s.name        = 'modelist'
  s.version     = Modelist::VERSION
  s.authors     = ['Gary S. Weaver']
  s.email       = ['garysweaver@gmail.com']
  s.homepage    = 'https://github.com/garysweaver/modelist'
  s.summary     = %q{Tests and analyzes requirements of your ActiveRecord models.}
  s.description = %q{CLI and API to perform basic testing of all models, their attributes, and their associations, and determine what models are depended on directly and indirectly by a specific model.}
  s.files = Dir['lib/**/*'] + ['Rakefile', 'README.md']
  s.license = 'MIT'
  s.add_dependency 'thor'
  s.add_runtime_dependency 'rails'
  s.executables = %w(modelist)
  s.require_paths = ["lib"]
end
