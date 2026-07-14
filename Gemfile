source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.2.11'
gem 'rails', '~> 7.0.4'

gem 'pg', '>= 0.18', '< 2.0' #"pg", "~> 1.1"
gem 'puma', '~> 7.0'   # was '~> 3.11'
gem 'sass-rails', '~> 5.0'
gem 'uglifier', '>= 1.3.0'
# gem 'mini_racer', platforms: :ruby
# gem 'coffee-rails', '~> 4.2'
# gem 'turbolinks', '~> 5'

gem 'mini_magick', '~> 4.8'

gem "sprockets-rails"
gem 'jsbundling-rails'
gem "turbo-rails"
gem "stimulus-rails"
gem 'cssbundling-rails'
gem 'jbuilder', '~> 2.5'

#

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.1.0', require: false

gem 'devise'
gem 'rest-client', '>= 2.0' ## Causes Non breaking Errors
gem 'bootstrap-sass', '~> 3.3.6'
gem 'kaminari' # Pagination
gem 'textacular' # Searching
gem 'pg_search'
gem 'cancancan'
gem 'whenever'
gem "chartkick" # charts http://chartkick.com/
gem 'groupdate' # for charts https://github.com/ankane/groupdate
gem 'colorize' #colorize puts output
gem 'json' #organize json objects
gem 'awesome_print' #color print   Type ap before User.last
gem 'rails_12factor'
# gem 'httparty'  ## Causes Non breaking Errors
# gem 'aws-sdk-s3' ## Causes Non breaking Errors
gem 'will_paginate'
gem 'will_paginate-bootstrap'
gem 'alphabetical_paginate'
gem "net-http"
# gem 'nio4r', '~> 2.5.8'
gem 'nio4r', '>= 2.6.0'
gem "acts_as_list", "~> 1.0"
gem "ranked-model", "~> 0.4.8"
gem 'quickbooks-ruby'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'rspec-rails'
  gem 'launchy'
  gem 'pry'
  gem 'shoulda-matchers'
  # gem 'capybara' ## Causes Non breaking Errors
  gem 'factory_bot_rails'
  gem 'simplecov', require: false
  gem "phantomjs"
  gem "poltergeist"
  gem 'database_cleaner'
  gem 'dotenv-rails' #for env auth
  gem 'rb-readline'
end

group :development do
  gem 'foreman'
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  # gem 'listen', '>= 3.0.5', '< 3.2' #off for upgrade
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  # gem 'spring-watcher-listen', '~> 2.0.0' #off for upgrade
end


# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
#JR you turned off to avoid warning: https://github.com/tzinfo/tzinfo-data/issues/12#issuecomment-279554001
# gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]
