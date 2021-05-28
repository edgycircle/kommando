require_relative 'lib/kommando/version'

Gem::Specification.new do |spec|
  spec.name          = 'edgycircle_kommando'
  spec.version       = Kommando::VERSION.dup
  spec.authors       = ['David Strauß']
  spec.email         = ['david.strauss@edgycircle.com']
  spec.description   = 'Command architecture building blocks.'
  spec.summary       = ''
  spec.homepage      = 'https://github.com/edgycircle/kommando'
  spec.license       = 'Nonstandard'

  spec.require_paths = %w[lib]

  spec.files         = Dir.glob('lib/**/*, db/**/*')

  spec.required_ruby_version = Gem::Requirement.new('>= 2.7.0')

  spec.add_runtime_dependency('pg')

  spec.add_development_dependency('dry-validation')
  spec.add_development_dependency('rails')
  spec.add_development_dependency('rubocop')
end
