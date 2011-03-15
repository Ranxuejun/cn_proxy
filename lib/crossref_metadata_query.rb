require 'open-uri'
require 'cgi'

$LOAD_PATH.unshift File.join(File.dirname(__FILE__),'lib')
require 'errors'

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
      raise UnknownDoi
    when  /Unable to parse or validate the xml query/
      raise QueryFailure
    when /Malformed DOI/
      raise UnknownDoi
    when  /not found in CrossRef/
      raise UnknownDoi
    when /The login you supplied is not recognized/
      raise QueryFailure
    else
      raise QueryFailure
    end
  end
end
