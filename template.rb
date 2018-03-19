# set ruby version
create_file '.ruby-version', "#{RUBY_VERSION}\n"

# remove this gem if your machine is not Windows
gsub_file('Gemfile', /^\s*gem\s*("|')tzinfo-data.*$\n/, '')

# remove comment lines from Gemfile
gsub_file('Gemfile', /^#.*$\n/, '')


# add files to be ignored by git
append_file '.gitignore' do 
  <<-EOF
  /config/database.yml
  /config/secrets.yml
  EOF
end

# make a copy of database.yml
# as database.yml.example
run 'cp config/database.yml{,.example}'

# make copy of secrets.yml and leave blank
file 'config/secrets.yml.example', <<-EOF
development:
  secret_key_base: 

test:
  secret_key_base: 

production:
  secret_key_base: <%= ENV["SECRET_KEY_BASE"] %>
EOF

# setup database
run 'rails db:setup'
run 'rails db:migrate'

if yes?("Do you need me to setup RSpec?")
  # install test development dependencies
  gem_group :development, :test do
    gem 'rspec-rails', '~> 3.0'
    gem 'capybara', '~> 2.11'
    gem 'launchy', '~> 2.4'
    gem 'selenium-webdriver', '~> 3.0'
    gem 'factory_bot_rails', '~> 4.8'
    gem 'faker', '~> 1.8'
  end

  gem_group :test do
    gem 'shoulda-matchers', '~> 3.0'
    gem 'database_cleaner', '~> 1.5'
  end

  # install gems
  run 'bundle install'

  # generate rspec files
  generate 'rspec:install'

  # create shoulda config file
  file 'spec/support/shoulda.rb', <<-RUBY
  Shoulda::Matchers.configure do |config|
    config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end
  RUBY

  # create factory_bot config file
  file 'spec/support/factory_bot_syntax.rb', <<-RUBY
  RSpec.configure do |config|
    config.include FactoryBot::Syntax::Methods
  end
  RUBY

  # create database_cleaner config file
  file 'spec/support/database_cleaner.rb', <<-RUBY
  RSpec.configure do |config|
    config.before(:suite) do
      DatabaseCleaner.clean_with(:truncation)
    end

    config.before(:each) do
      DatabaseCleaner.strategy = :transaction
    end

    config.before(:each, :js => true) do
      DatabaseCleaner.strategy = :truncation
    end

    config.before(:each) do
      DatabaseCleaner.start
    end

    config.after(:each) do
      DatabaseCleaner.clean
    end
  end
  RUBY

  # require capybara
  inject_into_file 'spec/rails_helper.rb', <<-EOF, :after => /require \'rspec\/rails\'.*$\n/
  require 'capybara/rails'
  EOF

  # comment out fixture
  comment_lines 'spec/rails_helper.rb', "config.fixture_path"

  # uncomment line for loading support files
  uncomment_lines 'spec/rails_helper.rb', /spec\/support\/\*/

  # set fixture use to false
  gsub_file('spec/rails_helper.rb', 'config.use_transactional_fixtures = true', 'config.use_transactional_fixtures = false')

  # remove mini test folder
  # will be using rspec
  remove_dir 'test'
end

# install gems
run 'bundle install'

# commit changes
after_bundle do
  git :init
  git add: "."
  git commit: '-m "Initial commit"'
end
