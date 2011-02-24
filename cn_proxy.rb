require 'rubygems'
require 'sinatra'
require 'json'
require 'uuid'
require 'time'

$LOAD_PATH.unshift File.join(File.dirname(__FILE__),'lib')
require 'helpers'
require 'errors'
require 'crossref_metadata_query'
require 'crossref_metadata_results'
require 'crossref_metadata_record'

mime_type :rdf, "application/rdf+xml"
mime_type :unixref, "application/unixref+xml"
mime_type :ttl, "text/turtle"
mime_type :jsonrdf, "application/rdf+json"

configure do
  set :query_pid, YAML.load_file("#{Dir.pwd}/config/settings.yaml")['query_pid']
  set :show_exceptions, false
end

before do
  handle_dois
end

get '/echo_doi/*', :provides => [:rdf, :json, :atom, :unixref, :ttl, :jsonrdf] do
  request.env['doi']
end

get '/*', :provides => [:rdf, :json, :atom, :unixref, :ttl, :jsonrdf] do
  raise InvalidDOI unless request.env['doi']
  render_representation options.query_pid
end

get '/*' do 
  raise InvalidDOI unless request.env['doi']
  redirect "http://dx.doi.org/#{request.env['doi']}", 303
end
