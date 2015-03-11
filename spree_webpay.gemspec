# encoding: UTF-8
Gem::Specification.new do |s|
  s.platform     = Gem::Platform::RUBY
  s.name         = 'spree_webpay'
  s.version      = '0.0.2'
  s.description  = 'A spree extension to use WebPay as a payment method'
  s.summary      = 'Spree::PaymentMethod::Webpay add as a new payment method for using WebPay'
  s.authors      = ['webpay', 'tomykaira']
  s.email        = ['administrators@webpay.jp', 'tomykaira@webpay.jp']
  s.homepage     = 'https://webpay.jp'
  s.license      = 'New-BSD'
  s.files        = `git ls-files`.split($/)
  s.test_files   = s.files.grep(%r{^spec/})
  s.require_path = ['lib']

  s.required_ruby_version = '>= 1.9.3'

  s.add_dependency 'spree_core', '~> 3.0.0'
  s.add_dependency 'webpay', '~> 3.1'

  s.add_development_dependency 'capybara', '~> 2.1'
  s.add_development_dependency 'coffee-rails'
  s.add_development_dependency 'database_cleaner'
  s.add_development_dependency 'rspec-rails',  '~> 3.0'
  s.add_development_dependency 'sass-rails', '~> 4.0.2'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'webpay-mock'
end
