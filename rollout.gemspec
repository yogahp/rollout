# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "rollout"
  s.version = "1.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["James Golick"]
  s.date = "2011-10-06"
  s.description = "Conditionally roll out features with redis."
  s.email = "jamesgoick@gmail.com"
  s.extra_rdoc_files = [
    "LICENSE",
    "README.rdoc"
  ]
  s.files = [
    ".document",
    "LICENSE",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "lib/rollout.rb",
    "rollout.gemspec",
    "spec/rollout_spec.rb",
    "spec/spec.opts",
    "spec/spec_helper.rb"
  ]
  s.homepage = "http://github.com/jamesgolick/rollout"
  s.require_paths = ["lib"]
  s.rubygems_version = "1.3.9.3"
  s.summary = "Conditionally roll out features with redis."

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rspec>, ["= 1.2.9"])
      s.add_development_dependency(%q<bourne>, ["= 1.0.0"])
      s.add_development_dependency(%q<redis>, ["= 0.1"])
    else
      s.add_dependency(%q<rspec>, ["= 1.2.9"])
      s.add_dependency(%q<bourne>, ["= 1.0.0"])
      s.add_dependency(%q<redis>, ["= 0.1"])
    end
  else
    s.add_dependency(%q<rspec>, ["= 1.2.9"])
    s.add_dependency(%q<bourne>, ["= 1.0.0"])
    s.add_dependency(%q<redis>, ["= 0.1"])
  end
end

