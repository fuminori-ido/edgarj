$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "edgarj/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "edgarj"
  s.version     = Edgarj::VERSION
  s.licenses    = ['MIT']
  s.authors     = ["Fuminori Ido"]
  s.email       = ["fuminori_ido@yahoo.co.jp"]
  s.homepage    = "https://github.com/fuminori-ido/edgarj"
  s.summary     = "Scaffold with Ajax, search, sort, 'belongs_to' popup, and more."
  s.description = <<EOM
Edgarj is an Ajax-based scaffold with QBE(Query By Example) search form,
column sort on record list,
popup view & controller for 'belongs_to' relation table to pick up a parent record,
csv download, and
user-role based access control.
EOM
  s.files = Dir["{app,config,db,lib,locale}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails",               '~> 4.0'
  s.add_dependency 'jquery-rails',        '~> 4.4', '>= 4.4.0'
  s.add_dependency 'jquery-ui-rails',     '~> 5.0', '>= 5.0.0'
  s.add_dependency 'config',              '~> 1.0.0'
  s.add_dependency "kaminari",            '~> 0.15'
  s.add_dependency "remotipart",          '~> 1.2'
  s.add_dependency 'awesome_nested_set',  '~> 3'
  s.add_dependency 'activerecord-session_store',  '~> 0.1'
  s.add_dependency 'sprockets',                   '~> 3.7.2'

  s.add_development_dependency "mysql2",          '~> 0.3.20'
end
