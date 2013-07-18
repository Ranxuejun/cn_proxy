# -*- coding: utf-8 -*-
ENV['RDF_RAPTOR_ENGINE'] = 'cli'

require 'cgi'
require 'json'
require 'crack'
require 'tilt'
require 'nokogiri'
require 'rdf/raptor'
require 'rdf/json'
require 'rdf/ntriples'
require 'date'

require_relative 'citeproc'
require_relative 'ris'
require_relative 'bibjson'
require_relative 'results'

helpers do

  FULLTEXT_REL = 'http://id.crossref.org/schema/fulltext'

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

  def detect_subdomain
    request.env['subdomain'] = request.env['SERVER_NAME'].split(/\./)[0]
  end

  def strip_route doi
    doi =~ /^\/(.*?)\/10\./ # detect route
    doi = $1 ? doi.sub(Regexp.new("^/#{$1}\/"),"") : doi.sub(Regexp.new("^/"),"") # remove route, or if their isn't a route, remove slash...
  end

  def is_valid_doi? text
    text =~ /^10\.\d{4,6}(\.[\.\w]+)*\/\S+$/
  end

  def is_valid_issn? issn
    issn =~ /^[0-9]{4}\-[0-9]+X?$/
  end

  def entire_url
    base = "http://#{request.env['SERVER_NAME']}"
    port = request.env['SERVER_PORT'] == 80 ? base : base = base +  ":#{request.env['SERVER_PORT']}"
    port = request.env['REQUEST_PATH'] ? port + request.env['REQUEST_PATH'] : port
    url = request.env['QUERY_STRING']  ? "#{port}?#{request.env['QUERY_STRING']}" : port
  end

  def accept_parameters
    request.env["HTTP_ACCEPT"].split(",").map do |ct|
      params = {}
      parts = ct.split(";")
      parts.drop(1).each do |kv|
        kv_parts = kv.split("=").map {|i| i.strip}
        params[kv_parts[0]] = kv_parts[1]
      end

      {
        :type => parts[0].strip,
        :params => params
      }
    end
  end

  def detect_mimes
    accepts = accept_parameters.reject { |a| !a[:params].key?("q") }.sort_by do |a|
      begin
        -a[:params]["q"].to_f
      rescue Exception => e
        0
      end
    end
    
    accepts = accepts + accept_parameters.reject { |a| a[:params].key?("q") }
    accepts.reverse
  end

  def detect_mime
    detect_mimes.first
  end

  def representation
    accepts = detect_mimes
    suffix = nil
    while suffix.nil? && !accepts.empty?
      rep = accepts.pop[:type]
      suffix = Rack::Mime::MIME_TYPES.key rep
      if !options.content_types.member?(suffix)
        suffix = nil
      end
    end

    raise UnknownContentType if suffix.nil?

    suffix
  end

  def render_feed feed_template, unixref
    # Fake several results. Will need to support this for eventual search results.
    metadata = Results.new
    record = Nokogiri::XML unixref
    metadata.records << CrossrefMetadataRecord.new(record, request.env['doi'])
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
    metadata = Results.new()
    record = Nokogiri::XML unixref
    metadata.records << Record.new(record, request.env['doi'])
    uuid = UUID.new
    template = Tilt.new("#{Sinatra::Application.root}/views/atom_feed.erb", :trim => '<>')
    xml = template.render( self, :metadata=>metadata, :feed_link => entire_url, :uuid => uuid, :feed_updated => Time.now.iso8601 )
    json = (Crack::XML.parse(xml)).to_json
  end

  def render_unixref format, unixref
    metadata = Results.new
    record = Nokogiri::XML unixref
    metadata.records << Record.new(record, request.env['doi'])

    render_rdf(format, metadata.to_graph, record.doi)
  end

  def render_rdf format, rdf, doi
    RDF::Writer.for(format).buffer do |writer|
      writer.prefixes = {
        :dct => RDF::DC,
        :owl => RDF::OWL,
        :foaf => RDF::FOAF,
        :prism => Rdf.prism,
        :bibo => Rdf.bibo,
        :rdf => Rdf.rdf
      }
      Munge.munge_rdf_output(writer, doi)
      writer << rdf
    end
  end

  def render_citeproc unixref
    xml = Nokogiri::XML unixref
    record = Record.new(xml, request.env['doi'])
    CiteProcHelper.new(record, settings).as_json
  end

  def render_bib_style unixref
    xml = Nokogiri::XML unixref
    record = Record.new(xml, request.env['doi'])
    params = accept_parameters[0][:params]

    opts = {}
    opts[:style] = params["style"] if params["style"]
    opts[:locale] = params["locale"] if params["locale"]
    opts[:id] = params["id"] if params["id"]
    opts[:format] = params["format"] if params["format"]

    CiteProcHelper.new(record, settings).as_style(opts)
  end

  def render_bibjson unixref
    xml = Nokogiri::XML unixref
    record = Record.new(xml, request.env['doi'])
    BibJson.from_record record
  end

  def render_ris unixref
    xml = Nokogiri::XML unixref
    record = Record.new(xml, request.env['doi'])
    Ris.from_record record
  end

  def render_bibtex unixref
    xml = Nokogiri::XML unixref
    record = Record.new(xml, request.env['doi'])
    CiteProcHelper.new(record, settings).as_style({:style => "bibtex"})
  end

  def fulltext_resources unixref
    xml = Nokogiri::XML unixref
    record = Record.new(xml, request.env['doi'])
    record.full_text_resources
  end

  def fulltext_data_link
    "http://data.crossref.org/fulltext/#{CGI.escape(request.env['doi'])}"
  end

  def data_link
    "http://data.crossref.org/#{CGI.escape(request.env['doi'])}"
  end

  def render_representation unixref
    case representation
    when ".x_bibtex"
      render_bibtex unixref
    when ".x_ris"
      render_ris unixref
    when ".unixref", ".vnd_unixref"
      unixref
    when ".json"
      render_json unixref
    when ".atom"
      render_feed :atom_feed, unixref
    when ".ttl"
      render_unixref :turtle, unixref
    when ".rdf"
      render_unixref :rdfxml, unixref
    when ".jsonrdf"
      render_unixref :json, unixref
    when ".ntriples"
      render_unxiref :ntriples, unixref
    when ".javascript"
      "metadata_callback(#{render_unixref(:json, unixref).strip});"
    when ".citeproc", ".vnd_citeproc"
      render_citeproc unixref
    when ".bibo", ".x_bibo"
      render_bib_style unixref
    when ".bibjson"
      render_bibjson unixref
    end
  end

  def link_header resources
    links = []
    resources.each_pair do |type, location|
      if type == :generic
        links << "<#{fulltext_data_link}>; rel=\"#{FULLTEXT_REL}\"; anchor=\"#{location}\""
      else
        links << "<#{fulltext_data_link}>; rel=\"#{FULLTEXT_REL}\"; type=\"#{type}\"; anchor=\"#{location}\""
      end
    end
    links.join(', ')
  end

  def render_with_fulltext_link unixref
    resources = fulltext_resources(unixref)
    if !resources.keys.empty?
      response['Link'] = link_header(resources)
    end
    render_representation(unixref)
  end

  def redirect_fulltext_link resources
    mime = detect_mime[:type]
    if resources.has_key?(mime)
      redirect(resources[mime])
    elsif resources.has_key?(:generic)
      redirect(resources[:generic])
    else
      response['Link'] = link_header(resources)
      status 406
      body "Full text representation types for this DOI: #{resources.keys.join(', ')}"
    end
  end

end

