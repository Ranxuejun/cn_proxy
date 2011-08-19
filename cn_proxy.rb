require 'rubygems'
require 'sinatra'
require 'json'
require 'uuid'
require 'time'
require 'json'

require_relative 'lib/helpers'
require_relative 'lib/errors'
require_relative 'lib/crossref_metadata_query'
require_relative 'lib/crossref_metadata_results'
require_relative 'lib/crossref_metadata_record'
require_relative 'lib/crossref_latest'

mime_type :rdf, "application/rdf+xml"
mime_type :unixref, "application/unixref+xml"
mime_type :ttl, "text/turtle"
mime_type :jsonrdf, "application/rdf+json"
mime_type :javascript, "text/javascript"

configure do
  set :query_pid, YAML.load_file("#{Dir.pwd}/config/settings.yaml")['query_pid']
  set :show_exceptions, false
end

before do
  tidy_request_for_testing
  detect_doi
  detect_subdomain
end

after do
  response.headers['Vary'] = 'Accept' if response.status == 200
end

get '/heartbeat' do
  {:pid => Process.pid, :status => "OK"}.to_json
end

def serve_published_list date
  if date <= Date.today - 7
    status 400
    "Too far in the past."
  else
    cache = Latest::DailyListCache.new
    cache.get_published representation, date
  end
end

def serve_filed_list date
  if date <= Date.today - 7
    status 400
    "Too far in the past."
  else
    cache = Latest::DailyListCache.new
    cache.get_filed representation, date
  end
end

get "/publishedlists/yesterday" do
  serve_published_list Date.today - 1
end

get "/publishedlists/1-day-ago" do
  serve_published_list Date.today - 1
end

get "/publishedlists/:days-days-ago" do
  serve_published_list Date.today - params[:days].to_i
end

get "/filedlists/yesterday" do
  serve_filed_list Date.today - 1
end

get "/filedlists/1-day-ago" do
  serve_filed_list Date.today - 1
end

get "/filedlists/:days-days-ago" do
  serve_filed_list Date.today - params[:days].to_i
end

get '/issn/:issn', :provides => [:javascript, :rdf, :ttl, :jsonrdf] do
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
    when ".javascript"
      "metadata_callback(#{render_rdf(:json, rdf).strip});"
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

get '/*', :provides => [:javascript, :rdf, :json, :atom, :unixref, :ttl, :jsonrdf] do
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
