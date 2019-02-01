# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'sidekiq_unique_jobs/version'

Gem::Specification.new do |spec|
  spec.name          = 'sidekiq-unique-jobs'
  spec.version       = SidekiqUniqueJobs::VERSION
  spec.authors       = ['Mikael Henriksson']
  spec.email         = ['mikael@zoolutions.se']

  spec.summary       = 'Prevent duplicate jobs in Sidekiq'
  spec.description   = 'An attempt to prevent simultaneous Sidekiq jobs with the same unique arguments to run'
  spec.homepage      = 'https://mhenrixon.github.com/sidekiq-unique-jobs'
  spec.license       = 'MIT'

  if spec.respond_to?(:metadata)
    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/mhenrixon/stub_requests"
    spec.metadata["changelog_uri"] = "https://github.com/mhenrixon/stub_requests/CHANGELOG.md"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.bindir        = 'bin'
  spec.executables   = %w[uniquejobs]

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject do |file|
      file.match(%r{^(test|spec|features|gemfiles|pkg|rails_example|tmp)/})
    end
  end

  spec.require_paths = ['lib']
  spec.add_dependency 'concurrent-ruby', '~> 1.0', '>= 1.0.5'
  spec.add_dependency 'sidekiq', '>= 4.0', '< 6.0'
  spec.add_dependency 'thor', '~> 0'

  spec.add_development_dependency 'bundler', '>= 2.0'
  spec.add_development_dependency 'rspec',   '~> 3.7'
  spec.add_development_dependency 'rake',    '~> 12.3'
  spec.add_development_dependency 'timecop', '~> 0.9'
  spec.add_development_dependency 'rack-test'
  spec.add_development_dependency 'sinatra'

  # ===== Utilities =====
  spec.add_development_dependency "travis", ">= 1.8.9"

  # ===== Documentation =====
  spec.add_development_dependency "yard",          "~> 0.9.18"
  spec.add_development_dependency "redcarpet",     "~> 3.4"
  spec.add_development_dependency "github-markup", "~> 3.0"
  spec.add_development_dependency "github_changelog_generator", "~> 1.14"

  # ===== Release Management =====
  spec.add_development_dependency "gem-release", ">= 2.0"
end
