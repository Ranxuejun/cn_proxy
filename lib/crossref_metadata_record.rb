require 'rexml/document'
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

  def owner_prefix
    return @record.root.elements["//doi_record"].attributes['owner']
  end

  def publication_type
    return :journal if @record.root.elements["//journal"]
    return :book if @record.root.elements["//book"]
    return :dissertation if @record.root.elements["//dissertation"]
    return :conference if @record.root.elements["//conference"]
    return :report if @record.root.elements["//report-paper"]
    return :standard if @record.root.elements["//standard"]
    return :database if @record.root.elements["//database"]
    return :unknown
  end

  def bibo_things
    case publication_type
    when :journal then {
        :component => "bibo:AcademicArticle",
        :container => "bibo:Journal",
        :container_id => "urn:issn:#{preferred_issn}"
      }
    when :confproc then {
        :component => "bibo:AcademicArticle",
        :container => "bibo:Proceedings",
        :container_id => "urn:isbn:#{isbn}"
      }
    when :report then {
        :component => "bibo:Report",
        :container => nil
      }
    when :standard then {
        :component => "bibo:Standard",
        :container => nil
      }
    when :dissertation then {
        :component => "bibo:Thesis",
        :container => nil
      }
    when :database then {
        :component => "owl:Thing",
        :container => nil
      }
    when :book then {
        :component => "bibo:Book"
        :container => nil
      }
    end
  end

  def doi
    @record.root.elements["//doi"].text
  end

  def publication_title
    #return @record.root.elements["//full_title"].text 
    return ""
  end

  def eissn
    return issn_of_type 'electronic' 
  end

  def pissn
    return issn_of_type 'print' 
  end

  def preferred_issn
    return (pissn and not pissn.empty?) ? pissn : eissn
  end

  def isbn
    return @record.root.elements['//isbn'].text
  end

  def title
    return  @record.root.elements["//title"].text 
  end

  def volume
    return  @record.root.elements["//volume"].text
  end

  # Unused in templates
  def issue
    return  @record.root.elements["//issue"].text
  end

  def edition_number
    return @record.root.elements["//edition_number"].text
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

  # Unused in templates
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
