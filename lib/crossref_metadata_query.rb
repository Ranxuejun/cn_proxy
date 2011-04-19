require 'open-uri'
require 'cgi'
require 'net/http'

$LOAD_PATH.unshift File.join(File.dirname(__FILE__),'lib')
require 'errors'

class CrossrefMetadataQuery

  attr_reader :unixref

  def self.for_doi doi, pid
    safe_doi = CGI.escape doi
    Net::HTTP.start "www.crossref.org" do |http|
      http.open_timeout = 30
      http.read_timeout = 30

      begin
        r = http.get "/openurl/?id=#{safe_doi}&noredirect=true&pid=#{pid}&format=unixref"
        raise QueryFailure unless r.code == "200"
        unixref = r.body
        scrape_for_errors unixref
        unixref
      rescue TimeoutError => e
        raise QueryTimeout
      end
    end
  end

  def self.scrape_for_errors unixref
    case unixref
    when /\<journal/, /\<conference/, /\<book/, /\<dissertation/, /\<report-paper/, /\<standard/, /\<database/
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
