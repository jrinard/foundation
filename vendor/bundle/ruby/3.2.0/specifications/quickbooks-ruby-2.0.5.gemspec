# -*- encoding: utf-8 -*-
# stub: quickbooks-ruby 2.0.5 ruby lib

Gem::Specification.new do |s|
  s.name = "quickbooks-ruby".freeze
  s.version = "2.0.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Cody Caughlan".freeze]
  s.date = "2024-07-25"
  s.description = "QBO V3 REST API to Quickbooks Online".freeze
  s.email = "toolbag@gmail.com".freeze
  s.homepage = "http://github.com/ruckus/quickbooks-ruby".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.6".freeze)
  s.rubygems_version = "3.4.19".freeze
  s.summary = "REST API to Quickbooks Online".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<oauth2>.freeze, ["< 3.0"])
  s.add_runtime_dependency(%q<roxml>.freeze, ["~> 4.2"])
  s.add_runtime_dependency(%q<activemodel>.freeze, ["> 4.0"])
  s.add_runtime_dependency(%q<net-http-persistent>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<nokogiri>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<multipart-post>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<faraday>.freeze, ["< 3.0"])
  s.add_runtime_dependency(%q<faraday-multipart>.freeze, ["~> 1.0", ">= 1.0.4"])
  s.add_runtime_dependency(%q<faraday-gzip>.freeze, [">= 1.0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<simplecov>.freeze, [">= 0"])
  s.add_development_dependency(%q<rr>.freeze, [">= 0"])
  s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
  s.add_development_dependency(%q<webmock>.freeze, [">= 0"])
  s.add_development_dependency(%q<dotenv>.freeze, [">= 0"])
end
