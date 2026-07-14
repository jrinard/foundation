# -*- encoding: utf-8 -*-
# stub: textacular 5.5.1 ruby lib

Gem::Specification.new do |s|
  s.name = "textacular".freeze
  s.version = "5.5.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Ben Hamill".freeze, "ecin".freeze, "Aaron Patterson".freeze, "Greg Molnar".freeze]
  s.date = "2022-01-03"
  s.description = "Textacular exposes full text search capabilities from PostgreSQL, extending\n    ActiveRecord with scopes making search easy and fun!".freeze
  s.email = ["git-commits@benhamill.com".freeze, "ecin@copypastel.com".freeze]
  s.homepage = "http://textacular.github.com/textacular".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.19".freeze
  s.summary = "Textacular exposes full text search capabilities from PostgreSQL".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<pg>.freeze, [">= 0"])
  s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
  s.add_development_dependency(%q<database_cleaner>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<pry>.freeze, [">= 0"])
  s.add_development_dependency(%q<pry-doc>.freeze, [">= 0"])
  s.add_development_dependency(%q<byebug>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<activerecord>.freeze, [">= 5.0", "< 7.1"])
end
