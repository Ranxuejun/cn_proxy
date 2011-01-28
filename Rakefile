require 'rubygems'
require 'rake'
require 'rake/clean'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'rake/testtask'
require 'rspec/core/rake_task'
require 'erb'
require 'highline/import'

spec = Gem::Specification.new do |s|
  s.name = 'cn_proxy'
  s.version = '0.0.1'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README', 'LICENSE']
  s.summary = 'Content Negotiation proxy for CrossRef OpenURL API'
  s.description = s.summary
  s.author = ''
  s.email = ''
  s.files = %w(LICENSE README Rakefile) + Dir.glob("{bin,lib,spec}/**/*")
  s.require_path = "lib"
  s.bindir = "bin"
end

Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
  p.need_tar = true
  p.need_zip = true
end

Rake::RDocTask.new do |rdoc|
  files =['README', 'LICENSE', 'lib/**/*.rb']
  rdoc.rdoc_files.add(files)
  rdoc.main = "README" # page to start on
  rdoc.title = "cn_proxy Docs"
  rdoc.rdoc_dir = 'doc/rdoc' # rdoc output folder
  rdoc.options << '--line-numbers'
end

Rake::TestTask.new do |t|
  t.test_files = FileList['test/**/*.rb']
end

RSpec::Core::RakeTask.new do |t|
  t.rspec_opts = ["-c", "-f progress", "-r ./spec/spec_helper.rb"]
  t.pattern = 'spec/**/*_spec.rb'
end

desc "Construct vhosts configuration file."
task :build_vhosts
  apply_template 'config/__vhosts'
end

desc "Construct cnproxy configuration file."
task :build_config
  apply_template 'config/__settings.yaml'
end

def apply_template filename
  erb = ERB.new(File.read(vhosts))
  File.open(target_filename(vhosts), 'w') { |f|
    f.write(erb.result(binding))
  }
end

def target_filename template
  target = File.join(File.dirname(template),File.basename(template).sub(/^__/,''))
end




