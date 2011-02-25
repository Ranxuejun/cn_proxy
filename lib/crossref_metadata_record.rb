require 'rubygems'
require 'rexml/document'
include REXML
require 'unidecode'
require 'crossref_metadata_rdf'

# Awful patch for rdf library on ruby 1.8.7 .
class StringIO
  def readpartial n
    sysread n
  end
end

class CrossrefMetadataRecord

  attr_reader :contributors

  class Contributor

    attr_reader :ordinal

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

    def name
      if @xml.elements['given_name'] then
        @xml.elements['given_name'].text + ' ' + @xml.elements['surname'].text
      else
        @xml.elements['surname'].text
      end
    end

    def slug
      decoded = Unidecoder.decode name.strip
      decrufted = decoded.gsub(/\./, ' ').gsub(/\s+/, '-').downcase
      slug_str = ''
      decrufted.each_byte do |c|
        if (c >= ?a and c <= ?z) or c == ?- then
          slug_str << c.chr
        end
      end
      slug_str
    end

    def unique_slug
      if ordinal and ordinal != 0 then
        slug + '-' + ordinal.to_s
      else
        slug
      end
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
    when :conference then {
        :component => "bibo:Article",
        :container => "bibo:Proceedings",
        :container_id => "urn:isbn:#{isbn}"
      }
    when :report then {
        :component => "bibo:Report"
      }
    when :standard then {
        :component => "bibo:Standard"
      }
    when :dissertation then {
        :component => "bibo:Thesis"
      }
    when :database then {
        :component => "owl:Thing"
      }
    when :book then {
        :component => "bibo:Book"
      }
    else {}
    end
  end

  def maybe_text path
    element = @record.root.elements[path]
    element.text if element
  end

  def doi
    last_doi = nil
    @record.root.elements.each("//doi") do |doi|
      last_doi = doi
    end
    return last_doi.text
  end

  def publication_title
    maybe_text '//full_title' or maybe_text '//proceedings_title'
  end

  def title
    maybe_text '//title'
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
    maybe_text '//isbn'
  end

  def volume
    maybe_text '//volume'
  end

  # Unused in templates
  def issue
    maybe_text '//issue'
  end

  def edition_number
    maybe_text '//edition_number'
  end

  def first_page
    maybe_text '//first_page'
  end

  def last_page
    maybe_text '//last_page'
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

  # Unused in templates
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
    @record.root.each_element("//issn") { |issn|
      return issn.text if issn.attributes['media_type'] == type 
      return issn.text if issn.attributes['media_type'] == nil and type == 'print'
    }
    return nil
  end

  def add_contributors
    @contributors = Array.new 
    @record.root.elements.each("//contributors/person_name") do |contributor_node|
      @contributors << c = Contributor.new( contributor_node )     
    end
  end

  def contributor_path c
    'contributors/' + doi + '/' + c.unique_slug
  end

  def maybe_tag name, content
    if content and not content.empty? then
      "<#{name}>#{content}</#{name}>"
    else
      ""
    end
  end

  def to_graph
    CrossrefMetadataRdf.create_graph self
  end

end
