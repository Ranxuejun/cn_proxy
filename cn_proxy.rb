require 'rubygems'
require 'sinatra'
require 'json'
require 'uuid'
require 'time'
require 'json'

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
  tidy_request_for_testing
  detect_doi
  detect_subdomain
end

get '/heartbeat' do
  {:pid => Process.pid}.to_json
end

get '/issn/:issn', :provides => [:rdf, :ttl, :jsonrdf] do
  raise MalformedIssn unless is_valid_issn? params[:issn]

  if request.env['subdomain'] == 'id' then
    redirect "http://data.crossref.org/issn/#{params[:issn]}", 303
  else

    rdf = CrossrefMetadataRdf.create_for_issn params[:issn]
    case representation
    when ".rdf"
      render_rdf :rdfxml, rdf
    when ".ttl"
      render_rdf :turtle, rdf
    when ".jsonrdf"
      render_rdf :json, rdf
    end

  end
end

get '/issn/:issn' do
  raise MalformedIssn unless is_valid_issn? params[:issn]

  if request.env['subdomain'] == 'id' then
    redirect "http://data.crossref.org/issn/#{params[:issn]}", 303
  else
    raise UnknownContentType
  end
end

get '/*', :provides => [:rdf, :json, :atom, :unixref, :ttl, :jsonrdf] do
  raise MalformedDoi unless request.env['doi']

  if request.env['subdomain'] == 'id' then
    redirect "http://data.crossref.org/#{request.env['doi']}", 303
  else
    uxr = CrossrefMetadataQuery.for_doi(request.env['doi'], options.query_pid)
    render_representation uxr
  end
end

get '/*' do 
  raise MalformedDoi unless request.env['doi']
  
  if request.env['subdomain'] == 'id' then
    redirect "http://dx.doi.org/#{request.env['doi']}", 303
  else
    raise UnknownContentType
  end
end
