require "oai"
require "rdf/raptor"
require "rdf/json"
require "nokogiri"
require "uri"
require "net/http"
require "memcache"
require "date"

class CrossrefLatestCache

  class Collector
    def initialize
      @cut_off_date = Date.today - 2
      @records = []

      resumption_token = append_records nil

      while not resumption_token.nil?
        resumption_token = append_records resumption_token
      end
    end

    def append_records resumption_token
      puts "#{Time.now}: Collecting more records"

      query = "verb=ListRecords&metadataPrefix=cr_unixml"
      query += "&from=#{@cut_off_date.strftime('%Y-%m-%d')}"
      query += "&until=#{(@cut_off_date + 1).strftime('%Y-%m-%d')}"
      unless resumption_token.nil?
        query += "&resumptionToken=" + resumption_token
      end
      
      uri_details = {
        :host => "oai.crossref.org",
        :path => "/OAIHandler",
        :query => query
      }
      uri = URI::HTTP.build uri_details
      new_token = nil

      Net::HTTP.start uri.host, :read_timeout => 600, :open_timeout => 600 do |http|
        response = http.get uri.request_uri

        if response.code.to_i == 200
          doc = Nokogiri::XML::Document.parse response.body
          @records = @records + parse_records(doc)
          puts "#{Time.now}: Candidate record count #{@records.count}"
          new_token = parse_resumption_token doc
        end
      end
      
      new_token
    end
      
    def parse_records doc
      ns = {"cr" => "http://www.crossref.org/xschema/1.0"}

      records = doc.xpath("//cr:crossref", ns).map do |metadata|
        year = metadata.at_xpath(".//cr:year", ns)
        month = metadata.at_xpath(".//cr:month", ns)
        day = metadata.at_xpath(".//cr:day", ns)

        record = nil

        begin
          if !(year.nil? || month.nil? || day.nil?)
            date = Date.civil year.text.to_i, month.text.to_i, day.text.to_i
            if date >= @cut_off_date && date <= (@cut_off_date + 1)
              record = {
                :doi => metadata.at_xpath(".//cr:doi", ns).text.sub("info:doi/", ""),
                :date => date
              }
            end
          end
        rescue StandardError => e
          puts "Exception for a record: #{e}"
        end

        record
      end

      records.compact
    end

    def parse_resumption_token doc
      token_element = doc.at_xpath("//xmlns:resumptionToken")
      if token_element.nil?
        nil
      else
        token_element.text
      end
    end

    def as_rdf
      RDF::Graph.new do |graph|
        @records.each do |record|
          uri = RDF::URI.new("http:dx.doi.org/" + record[:doi])
          graph << [uri, RDF::DC.identifier, record[:doi]]
          graph << [uri, RDF::DC.date, record[:date]]
        end
      end
    end
  end
  
  def initialize
    @cache = MemCache.new "localhost:11211", :namespace => "cnproxy"
  end

  def populate
    rdf = Collector.new.as_rdf

    {"ttl" => :turtle, "rdf" => :rdfxml}.each_pair do |suffix, format|
      content = RDF::Writer.for(format).buffer do |writer|
        writer << rdf
      end
      # TODO Filter releases and changes.
      @cache.set "releases_" + suffix, content
      @cache.set "changes_" + suffix, content
    end
  end

  def get_releases suffix
    @cache.get "releases_" + suffix
  end

  def get_changes suffix
    @cache.get "changes_" + suffix
  end

end

