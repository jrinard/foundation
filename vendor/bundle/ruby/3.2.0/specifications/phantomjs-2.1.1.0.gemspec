# -*- encoding: utf-8 -*-
# stub: phantomjs 2.1.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "phantomjs".freeze
  s.version = "2.1.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Christoph Olszowka".freeze]
  s.date = "2016-01-29"
  s.description = "Auto-install phantomjs on demand for current platform. Comes with poltergeist integration.".freeze
  s.email = ["christoph at olszowka.de".freeze]
  s.homepage = "https://github.com/colszowka/phantomjs-gem".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.19".freeze
  s.summary = "Auto-install phantomjs on demand for current platform. Comes with poltergeist integration.".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<poltergeist>.freeze, ["~> 1.5"])
  s.add_development_dependency(%q<capybara>.freeze, ["~> 2.4"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 2.99"])
  s.add_development_dependency(%q<simplecov>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
end
