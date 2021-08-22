require_relative "lib/distribute_reads/version"

Gem::Specification.new do |spec|
  spec.name          = "distribute_reads"
  spec.version       = DistributeReads::VERSION
  spec.summary       = "Scale database reads with replicas in Rails"
  spec.homepage      = "https://github.com/ankane/distribute_reads"
  spec.license       = "MIT"

  spec.author        = "Andrew Kane"
  spec.email         = "andrew@ankane.org"

  spec.files         = Dir["*.{md,txt}", "{lib}/**/*"]
  spec.require_path  = "lib"

  spec.required_ruby_version = ">= 2.4"

  spec.add_dependency "makara", ">= 0.3"
end
