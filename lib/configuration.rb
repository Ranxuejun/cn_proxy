require 'yaml'

config_file = File.join(File.dirname(__FILE__),'..','config','settings.yaml')
@settings = YAML.load(ERB.new(File.new(config_file).read).result)

configure do
  # Shared config
  set :crossref_api_key, @settings['crossref_api_key']
  set :port, @settings['port']
end

