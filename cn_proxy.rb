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
mime_type :vnd_unixref, "application/vnd.crossref.unixref+xml"
mime_type :ttl, "text/turtle"
mime_type :jsonrdf, "application/rdf+json"
mime_type :javascript, "text/javascript"
mime_type :vnd_citeproc, "application/vnd.citationstyles.csl+json"
mime_type :x_bibo, "text/x-bibliography"
mime_type :x_ris, "application/x-research-info-systems"
mime_type :x_bibtex, "application/x-bibtex"
mime_type :item, "application/vnd.crossref.item"
mime_type :bibjson, "application/bibjson+json"

# Deprecated types
mime_type :bibo, "text/bibliography"
mime_type :citeproc, "application/citeproc+json"
mime_type :unixref, "application/unixref+xml"

configure do
  def build_named_file_list glob
    files = Dir.glob(glob).map do |f|
      File.join(File.expand_path(File.dirname(__FILE__)), f)
    end
    names = {}
    files.each do |f|
      name = yield f
      names[name] = f
    end
    names
  end

  locales = build_named_file_list "locales/*.xml" do |f|
    File.basename(f, ".xml").gsub(/^locales-/, "")
  end

  styles = build_named_file_list "styles/*.csl" do |f|
    File.basename(f, ".csl")
  end

  set :query_pid, YAML.load_file("#{Dir.pwd}/config/settings.yaml")['query_pid']
  set :show_exceptions, false
  set :locales, locales
  set :styles, styles

  set :citeprocjs, File.join(File.expand_path(File.dirname(__FILE__)), "citeproc.gjs")
  set :xmle4xjs, File.join(File.expand_path(File.dirname(__FILE__)), "xmle4x.js")
  set :xmldomjs, File.join(File.expand_path(File.dirname(__FILE__)), "xmldom.js")
  set :bibliojs, File.join(File.expand_path(File.dirname(__FILE__)), "biblio.js")

  set :content_types, [".unixref", ".json", ".ttl", ".rdf",
                       ".jsonrdf", ".ntriples", ".javascript",
                       ".citeproc", ".bibo", ".vnd_citeproc",
                       ".vnd_unixref", ".x_bibo", ".x_ris",
                       ".x_bibtex", ".html", ".atom", ".item",
                       ".bibjson"]
end

before do
  tidy_request_for_testing
  detect_doi
  detect_subdomain
end

after do
  response.headers['Vary'] = 'Accept' if response.status == 200
  response.headers["Access-Control-Allow-Origin"] = "*"
end

get "/" do
  haml :index
end

get "/styles" do
  content_type "application/json"
  settings.styles.keys.to_json
end

get "/locales" do
  content_type "application/json"
  settings.locales.keys.to_json
end

get '/heartbeat' do
  response = {:pid => Process.pid}

  begin
    test_result_code = CrossrefMetadataQuery.test options.query_pid

    if test_result_code == 200
      response[:status] = "OK"
    else
      response[:status] = "Error"
      response[:message] = "OpenURL query failure"
      response[:code] = test_result_code
    end
  rescue StandardError => e
    response[:status] = "Error"
    response[:message] = e
  end

  response.to_json
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

get '/*', :provides => [:html, :javascript, :rdf, :json, :atom, :unixref, :ttl,
                        :jsonrdf, :citeproc, :bibo, :x_bibo, :vnd_unixref, :vnd_citeproc,
                        :x_ris, :x_bibtex, :item, :bibjson] do
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
