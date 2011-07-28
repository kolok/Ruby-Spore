# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

require "spore/version"

Gem::Specification.new do |s|
  s.name = %q{spore}
  s.version = "0.0.8"

  s.version     = Spore::VERSION
  s.platform    = Gem::Platform::RUBY

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Alexis Sukrieh <sukria@sukria.net> [sukria]", "Hery Ramihajamalala <hery@rails-royce.org> [hallelujah]"]
  s.date = %q{2011-07-28}
  s.description = %q{Spore is a specification for describing ReST API that can be parsed and used automatically by client implementations to communicate with the descibed API}
  s.email = %q{<sukria@sukria.net>}

  s.homepage = %q{http://github.com/sukria/Ruby-Spore}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{A Ruby implementation for SPORE}
  s.rubyforge_project = "spore"

  s.extra_rdoc_files = [
    "LICENSE",
    "README.rdoc"
  ]

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency(%q<test-unit>, [">= 2.1.0"])
  s.add_development_dependency(%q<rake>, [">= 0.8.7"])
  s.add_development_dependency(%q<rcov>, [">= 0.9.9"])

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<json>, [">= 1.4.6"])
      s.add_runtime_dependency(%q<httpclient>, ["= 2.1.7.2"])
    else
      s.add_dependency(%q<json>, [">= 1.4.6"])
      s.add_dependency(%q<httpclient>, ["= 2.1.7.2"])
    end
  else
    s.add_dependency(%q<json>, [">= 1.4.6"])
    s.add_dependency(%q<httpclient>, ["= 2.1.7.2"])
  end
end

