require 'rubygems'
require "nokogiri"


class CrossrefMetadataRecord

  attr_reader :contributors

  class Contributor
    def initialize node
      @xml = node
    end
    def sequence
      "sequence" 
    end
    def contributor_role
      "contributor_role" 
    end
    def surname
      "surname" 
    end
    def given_name
      "given_name" 
    end
  end

  def initialize metadata
    @record = Nokogiri::XML(metadata) { |config| config.strict }
    # Turn off namepaces.
    @record.remove_namespaces!()
    # STDERR.puts @record.xpath["//title"].text
    add_contributors
  end

  def owner_prefix
    return @record.xpath("//owner_name").text if node_exists?(@doc.xpath("//owner_name"))
  end

  def doi
    return @record.xpath('/doi_records/doi_record/crossref/journal/journal_article/doi_data/doi').text if node_exists?(@record.xpath('/doi_records/doi_record/crossref/journal'))
    return @record.xpath('/doi_records/doi_record/crossref/conference/conference_paper/doi_data/doi').text if node_exists?(@record.xpath('/doi_records/doi_record/crossref/conference'))
    raise "Invalid CrossRef Record"
  end

  def publication_title   
    @record.xpath("//full_title").text
  end

  def eissn
    return issn_of_type 'electronic' 
  end

  def pissn
    return issn_of_type 'print' 
  end

  def title
    "title" #   return @record.xpath["//title"].text
  end

  def volume
    return "volume" # @record.xpath["//volume"].text
  end

  def issue
    return  "issue" # @record.xpath["//issue"].text
  end

  def first_page
    "first_page" # return  @record.root.elements["//first_page"].text
  end

  def last_page
    "last_page" # return  @record.root.elements["//last_page"].text
  end

  def publication_year
    "publication_year" # return  @record.root.elements["//publication_date/year"].text.to_i if @record.root.elements["//publication_date/year"]
  end

  def publication_month
    "publication_month" # return  @record.root.elements["//publication_date/month"].text.to_i if  @record.root.elements["//publication_date/month"]
  end

  def publication_day
    "publication_day" # return  @record.root.elements["//publication_date/day"].text.to_i if @record.root.elements["//publication_date/day"]
  end

  def publication_date
    "publication_date" # return (publication_day and publication_month) ? "#{publication_year}-#{publication_month}-#{publication_day}" : "#{publication_year}"
  end

  def url
    "url" # return @record.root.elements["//resource"].text if @format == :unixref
  end

  def publisher_name
    #lookup_publisher unless @publisher
    "publisher_name" # return @publisher.root.elements["//publisher_name"].text
  end

  def publisher_location
    #lookup_publisher unless @publisher
    "publisher_location" # return @publisher.root.elements["//publisher_location"].text.gsub(/\n/,"")
  end

  private

  def node_exists? node
    return ! node.empty?
  end

  def issn_of_type type
    @record.xpath("//issn").each {|issn| return issn.text.sub("-","") if issn['media_type'] == type}
  end

  def lookup_publisher
    require 'net/http'
    prefix = owner_prefix
    results = Net::HTTP.get_response('www.crossref.org', "/getPrefixPublisher/?prefix=#{prefix}")
    raise CrossRefError, "Could not lookup publisher information: #{results.code}" unless results.code == "200"
    @publisher = REXML::Document.new(results.body)
  end

  def add_contributors
    @contributors = Array.new 
    @record.xpath("//contributors/person_name").each do |contributor_node|
      @contributors << c = Contributor.new( contributor_node )     
    end
  end


end