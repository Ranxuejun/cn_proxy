require 'rubygems'
require "rexml/document"
include REXML



class CrossrefMetadataRecord

  attr_reader :contributors

  class Contributor
    def initialize node
      @xml = node
    end
    def sequence
      return @xml.attributes['sequence'] if @xml.attributes['sequence']
    end
    def contributor_role
      return @xml.attributes['contributor_role'] if @xml.attributes['contributor_role']
    end
    def surname
      return @xml.elements["surname"].text if @xml.elements["surname"]
    end
    def given_name
      return @xml.elements["given_name"].text if @xml.elements["given_name"]
    end
  end


  def initialize record
    @record=record  
    add_contributors
  end

  # def timestamp
  #     return @xml.root.elements["//doi_record"].attributes["timestamp"] 
  #   end
  # 
    def owner_prefix
        return @record.root.elements["//doi_record"].attributes['owner']
      end
  # 
  #   def pubtype
  #     return "journal" if @xml.root.elements["//journal"]
  #     return "confproc" if @xml.root.elements["//confproc"]
  #   end
  # 
  #   def article_title
  #     return @xml.root.elements["//title"].text     
  #   end
  # 
  def doi
    @record.root.elements["//doi"].text
  end

  def publication_title
    return @record.root.elements["//full_title"].text 
  end

  def eissn
    return issn_of_type 'electronic' 
  end

  def pissn
    return issn_of_type 'print' 
  end
  # 
  #   def content_type
  #     return  @xml.root.elements["//journal_article"].attributes["publication_type"] 
  #   end

  def title
    return  @record.root.elements["//title"].text 
  end

  def volume
    return  @record.root.elements["//volume"].text
  end

  def issue
    return  @record.root.elements["//issue"].text
  end

  def first_page
    return  @record.root.elements["//first_page"].text
  end

  def last_page
    return  @record.root.elements["//last_page"].text
  end

  def publication_year
    return  @record.root.elements["//publication_date/year"].text.to_i if @record.root.elements["//publication_date/year"]
  end

  def publication_month
    return  @record.root.elements["//publication_date/month"].text.to_i if  @record.root.elements["//publication_date/month"]
  end

  def publication_day
    return  @record.root.elements["//publication_date/day"].text.to_i if @record.root.elements["//publication_date/day"]
  end

  def publication_date
    return (publication_day and publication_month) ? "#{publication_year}-#{publication_month}-#{publication_day}" : "#{publication_year}"
  end


  def url
    return @record.root.elements["//resource"].text if @format == :unixref
  end

  def publisher_name
    lookup_publisher unless @publisher
    return @publisher.root.elements["//publisher_name"].text
  end

  def publisher_location
    lookup_publisher unless @publisher
    return @publisher.root.elements["//publisher_location"].text.gsub(/\n/,"")
  end

  private

  def lookup_publisher
    require 'net/http'
    prefix = owner_prefix
    results = Net::HTTP.get_response('www.crossref.org', "/getPrefixPublisher/?prefix=#{prefix}")
    raise CrossRefError, "Could not lookup publisher information: #{results.code}" unless results.code == "200"
    @publisher = REXML::Document.new(results.body)
  end

  def issn_of_type type
    @record.root.each_element("//issn") {|issn| return issn.text.sub("-","") if issn.attributes['media_type'] == type }
  end

  def add_contributors
    @contributors = Array.new 
    @record.root.elements.each("//contributors/person_name") do |contributor_node|
      @contributors << c = Contributor.new( contributor_node )     
    end
  end


end