source "https://rubygems.org"

# Declare your gem's dependencies in edgarj.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

gem 'mysql2', '~> 0.3.20'
gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'remotipart'
gem 'kaminari'
gem 'config'
gem 'awesome_nested_set'
gem 'activerecord-session_store'
gem 'sprockets'

group :development, :test do
  gem 'byebug'
end

group :development do
  gem 'thin'

  # replacement of rdoc to generate document
  gem 'yard'
end

group :test do
  gem 'shoulda-context'
end
