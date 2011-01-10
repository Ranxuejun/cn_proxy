require 'cgi'
require 'json'
require 'crack'
require 'tilt'
require "rexml/document"

helpers do

  def dlog message
    pp(message,STDERR)
  end

  # TODO keep checking to see if I can avoid this hack
  # Spec doesn't seem to set REQUEST_URI for requests, so, in order to enable testing,
  # I need to repopulate it with a likely looking URL. 
  def tidy_request_for_testing 
    request.env['REQUEST_URI'] = request.env['PATH_INFO']
  end

  def detect_doi 
    doi = request.env['REQUEST_URI'] 
    doi = strip_route doi
    doi = CGI.unescape(doi)
    request.env['doi'] = (is_valid_doi? doi) ? doi : nil
  end

  def strip_route doi
    doi =~ /^\/(.*?)\/10\./ # detect route 
    doi = $1 ? doi.sub(Regexp.new("^/#{$1}\/"),"") : doi.sub(Regexp.new("^/"),"") # remove route, or if their isn't a route, remove slash...
  end

  def is_valid_doi? text
    text =~ /^10\.\d{4,5}(\.[\.\w]+)*\/\S+$/ 
  end

  def handle_dois
    tidy_request_for_testing   
    detect_doi
  end

  def entire_url
    base = "http://#{request.env['SERVER_NAME']}"
    port = request.env['SERVER_PORT'] == 80 ? base : base = base +  ":#{request.env['SERVER_PORT']}"
    port = request.env['REQUEST_PATH'] ? port + request.env['REQUEST_PATH'] : port
    url = request.env['QUERY_STRING']  ? "#{port}?#{request.env['QUERY_STRING']}" : port 
  end

  def representation
    Rack::Mime::MIME_TYPES.index(request.env['HTTP_ACCEPT'])
  end 

  def render_feed feed_template, unixref
    # Fake several results. Will need to support this for eventual search results.
    metadata = CrossrefMetadataResults.new()
    record = REXML::Document.new(unixref)
    metadata.records << CrossrefMetadataRecord.new(record) 
    uuid = UUID.new
    erb feed_template, :locals => { 
      :metadata => metadata, 
      :feed_link => entire_url, 
      :uuid => uuid, 
      :feed_updated => Time.now.iso8601 
    }  
  end

  def render_json unixref
    # Bascially translate the ATOM XML into JSON using Tilt to bind redenering to variable.
    metadata = CrossrefMetadataResults.new()
    record = REXML::Document.new(unixref)
    metadata.records << CrossrefMetadataRecord.new(record) 
    uuid = UUID.new
    template = Tilt.new("#{Sinatra::Application.root}/views/atom_feed.erb", :trim => '<>')
    xml = template.render( self, :metadata=>metadata, :feed_link => entire_url, :uuid => uuid, :feed_updated => Time.now.iso8601 )
    json = (Crack::XML.parse(xml)).to_json  
  end

  def render_representation
    unixref = CrossrefMetadataQuery.new(request.env['doi']).unixref
    case representation
    when ".unixref"
      unixref   
    when ".json"
      render_json unixref
    when ".atom"
      render_feed :atom_feed, unixref
    when ".ttl"
      render_feed :ttl_feed, unixref
    end
  end
end
