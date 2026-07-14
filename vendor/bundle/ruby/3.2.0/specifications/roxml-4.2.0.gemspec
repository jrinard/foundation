# -*- encoding: utf-8 -*-
# stub: roxml 4.2.0 ruby lib

Gem::Specification.new do |s|
  s.name = "roxml".freeze
  s.version = "4.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Ben Woosley".freeze, "Zak Mandhro".freeze, "Anders Engstrom".freeze, "Russ Olsen".freeze]
  s.date = "2021-09-09"
  s.description = "ROXML is a Ruby library designed to make it easier for Ruby developers to work with XML.\nUsing simple annotations, it enables Ruby classes to be mapped to XML. ROXML takes care\nof the marshalling and unmarshalling of mapped attributes so that developers can focus on\nbuilding first-class Ruby classes. As a result, ROXML simplifies the development of\nRESTful applications, Web Services, and XML-RPC.\n".freeze
  s.email = "ben.woosley@gmail.com".freeze
  s.extra_rdoc_files = ["History.txt".freeze, "README.rdoc".freeze]
  s.files = ["History.txt".freeze, "README.rdoc".freeze]
  s.homepage = "https://github.com/Empact/roxml".freeze
  s.rubygems_version = "3.4.19".freeze
  s.summary = "Ruby Object to XML mapping library".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<activesupport>.freeze, [">= 4.0"])
  s.add_runtime_dependency(%q<nokogiri>.freeze, [">= 1.3.3"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 0.9"])
  s.add_development_dependency(%q<juwelier>.freeze, [">= 0"])
  s.add_development_dependency(%q<minitest>.freeze, [">= 0"])
  s.add_development_dependency(%q<rexml>.freeze, [">= 0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.7.0"])
  s.add_development_dependency(%q<sqlite3>.freeze, [">= 1.2.4"])
  s.add_development_dependency(%q<activerecord>.freeze, [">= 4.0"])
  s.add_development_dependency(%q<rack>.freeze, ["< 2.0.0"])
  s.add_development_dependency(%q<equivalent-xml>.freeze, [">= 0.6.0"])
end
