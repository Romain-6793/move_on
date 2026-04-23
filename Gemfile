source "https://rubygems.org"

ruby "3.3.5"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.1.6"

# Minitest 6 est incompatible avec le line_filtering de Rails 7.1 (ArgumentError au lancement des tests).
gem "minitest", "~> 5.25"

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"

# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

gem "devise"

gem "bootstrap", "~> 5.3"
gem "autoprefixer-rails"
gem "font-awesome-sass", "~> 6.1"
gem "simple_form", github: "heartcombo/simple_form"
gem "sassc-rails"


# Control accesses depending on users

gem "pundit"

# Wizard multi-étapes pour le formulaire de recherche.
# Wicked fournit un DSL simple (steps, render_wizard) pour enchaîner
# plusieurs vues sous un seul contrôleur.
gem "wicked"

# For Background jobs (if needed...)

gem "solid_queue"

# For searching/filtering cities adding weight to some criterias

gem "pg_search"

# Assistant immobilier (RubyLLM + rendu markdown des réponses)
gem "ruby_llm", "~> 1.2.0"
gem "redcarpet", "~> 3.6"
# WickedPDF + son binaire wkhtmltopdf pour l'export PDF des recherches.
# wicked_pdf orchestre la conversion HTML→PDF depuis Rails.
# wkhtmltopdf-binary embarque le binaire natif (pas d'installation système requise).
gem "wicked_pdf"
gem "wkhtmltopdf-binary"

gem "aws-sdk-s3", require: false

group :development, :test do
  gem "dotenv-rails"
  # Faker génère des données réalistes pour les seeds (noms, textes, nombres…)
  gem "faker"
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[mri windows]
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
