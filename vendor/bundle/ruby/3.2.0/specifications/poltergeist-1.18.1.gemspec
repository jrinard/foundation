# -*- encoding: utf-8 -*-
# stub: poltergeist 1.18.1 ruby lib

Gem::Specification.new do |s|
  s.name = "poltergeist".freeze
  s.version = "1.18.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Jon Leighton".freeze]
  s.date = "2018-05-24"
  s.description = "Poltergeist is a driver for Capybara that allows you to run your tests on a headless WebKit browser, provided by PhantomJS.".freeze
  s.email = ["j@jonathanleighton.com".freeze]
  s.homepage = "https://github.com/teampoltergeist/poltergeist".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3".freeze)
  s.rubygems_version = "3.4.19".freeze
  s.summary = "PhantomJS driver for Capybara".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<capybara>.freeze, [">= 2.1", "< 4"])
  s.add_runtime_dependency(%q<websocket-driver>.freeze, [">= 0.2.0"])
  s.add_runtime_dependency(%q<cliver>.freeze, ["~> 0.3.1"])
  s.add_development_dependency(%q<launchy>.freeze, ["~> 2.0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.7"])
  s.add_development_dependency(%q<sinatra>.freeze, ["<= 3.0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<image_size>.freeze, ["~> 1.0"])
  s.add_development_dependency(%q<pdf-reader>.freeze, ["< 3.0", ">= 1.3.3"])
  s.add_development_dependency(%q<coffee-script>.freeze, ["~> 2.2"])
  s.add_development_dependency(%q<guard-coffeescript>.freeze, ["~> 2.0.0"])
  s.add_development_dependency(%q<coffee-script-source>.freeze, ["~> 1.12.2"])
  s.add_development_dependency(%q<listen>.freeze, ["~> 3.0.6"])
  s.add_development_dependency(%q<erubi>.freeze, [">= 0"])
end
