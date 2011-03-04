require 'open-uri'
require 'cgi'

class CrossRefError < StandardError
  attr_accessor :status
  def initialize(message, status)
    @status = status
    super(message)   
  end
end

class CrossrefMetadataQuery

  attr_reader :unixref

  def self.for_doi doi, pid
    safe_doi = CGI.escape doi
    # @unixref = File.open('test-data/article.xml', 'r').read
    unixref = open("http://www.crossref.org/openurl/?id=#{safe_doi}&noredirect=true&pid=#{pid}&format=unixref").read
    scrape_for_errors unixref
    unixref
  end

  def self.scrape_for_errors unixref
    case unixref
    when /\<journal\>/, /\<conference\>/, /\<book\>/, /\<dissertation\>/, /\<report-paper\>/, /\<standard\>/, /\<database\>/
      return
    when /doi_records/
      raise CrossRefError.new("Unknown doi_record type", '400')
    when  /Unable to parse or validate the xml query/
      #raise "400 Invalid DOI"
      raise CrossRefError.new("Invalid DOI", "400")
    when /Malformed DOI/
      #raise "400 Invalid DOI"
      raise CrossRefError.new("Invalid DOI", "400")
    when  /not found in CrossRef/
      #raise "404 DOI not found"
      raise CrossRefError.new("DOI not found. Are you sure it is a CrossRef DOI?", "404")
    when /The login you supplied is not recognized/
      #raise "403 Authentication failed"
      raise CrossRefError.new("Authentication failed.", "403")
    else
      raise "501 Internal Error"
    end
  end
end
