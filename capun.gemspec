# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'capun/version'

Gem::Specification.new do |spec|
  spec.name          = "capun"
  spec.version       = Capun::VERSION
  spec.authors       = ["Ivan Zamylin"]
  spec.email         = ["zamylin@yandex.ru"]
  spec.summary       = %q{Opinionated Rails deployment solution with CAPistrano, Unicorn and Nginx.}
  spec.description   = %q{Opinionated Rails deployment solution with CAPistrano, Unicorn and Nginx. It helps to make deployment easily, but preserves all the power of capistrano.}
  spec.homepage      = "https://github.com/zamylin/capun"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake", "~> 10.1"
  spec.add_dependency "capistrano", "~> 3.1"
  spec.add_dependency "capistrano-rails", "~> 1.1.1"
  spec.add_dependency "rvm1-capistrano3", "~> 1.2.2"
  spec.add_dependency "capistrano-bundler", "~> 1.1"
  spec.add_dependency "capistrano3-unicorn", "~> 0.1.1"
end
