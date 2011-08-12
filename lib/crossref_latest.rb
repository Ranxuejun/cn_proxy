require "oai"
require "rdf/raptor"
require "rdf/json"
require "nokogiri"
require "uri"
require "net/http"
require "memcache"
require "date"
require "mongo"

module Latest

  def self.bootstrap today
    collector = Collector.new({:query_from => today << 6})
    collector.collect
  end

end

class Latest::Storage
  
  def self.collection
    @conn ||= Mongo::Connection.new "localhost"
    @db ||= @conn.db "cnproxy"
    @db.collection "dois"
  end
  
end

class Latest::Collector
  
  def initialize options={}
    defaults = {
      :query_from => Date.today - 2
    }
    
    @date_options = defaults.merge options
  end

  def collect
    resumption_token = collect_records nil

    while not resumption_token.nil?
      resumption_token = collect_records resumption_token
    end
  end
  
  def collect_records resumption_token
    puts "#{Time.now}: Collecting more records"
    
    query = "verb=ListRecords&metadataPrefix=cr_unixml"
    query += "&from=#{@date_options[:query_from].strftime('%Y-%m-%d')}"
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

        records = parse_records doc
        puts "#{Time.now}: Found #{records.count} records"

        records.each do |record|
          coll = Latest::Storage.collection
          existing = coll.find_one({"doi" => record[:doi]})
          if existing.nil?
            coll.insert record
          else
            coll.update({"doi" => record[:doi]}, record)
          end
        end
        
        new_token = parse_resumption_token doc
      end
    end
    
    new_token
  end
  
  def parse_records doc
    ns = {
      "cr" => "http://www.crossref.org/xschema/1.0",
      "oai" => "http://www.openarchives.org/OAI/2.0/"
    }
    
    records = doc.xpath("//oai:record", ns).map do |metadata|
      record = nil
      
      begin
        year = metadata.at_xpath(".//cr:year", ns)
        month = metadata.at_xpath(".//cr:month", ns)
        day = metadata.at_xpath(".//cr:day", ns)
        file_date = Date.parse metadata.at_xpath(".//oai:datestamp", ns).text
        doi = metadata.at_xpath(".//cr:doi", ns).text.sub("info:doi/", "")

        record = {
          :doi => doi,
          :file_date => file_date.to_time
        }

        if !(year.nil? || month.nil? || day.nil?)
          pub_date = Date.civil year.text.to_i, month.text.to_i, day.text.to_i
          record[:pub_date] = pub_date.to_time
        end

        record[:pub_year] = year.text.to_i unless year.nil?
        record[:pub_month] = month.text.to_i unless month.nil?
        record[:pub_day] = day.text.to_i unless day.nil?
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

end

class Latest::DailyLists

  def initialize for_date
    @published = Storage.collection.find({:pub_date => for_date.to_time})
    @filed = Storage.collection.find({:file_date => for_date.to_time})
  end

  def to_rdf records
    RDF::Graph.new do |graph|
      records.each do |record|
        doi = RDF::URI.new("http://dx.doi.org/" + record[:doi])
        if record[:pub_date]
          graph << [doi, RDF::DC.date, record[:pub_date]]
        else
          graph << [doi, RDF::DC.date, record[:pub_year]]
        end
      end
    end
  end

  def to_filed_rdf
    to_rdf @filed
  end

  def to_pub_rdf
    to_rdf @published
  end
  
end

class Latest::DailyListCache

  def initialize
    @cache = MemCache.new "localhost:11211", :namespace => "cnproxy"
  end

  def update today
    # Update mongo to latest from oai pmh
    collector = Collector.new({:query_from => today - 2})
    collector.collect

    # Create yesterday's RDF
    yesterday = today - 1
    oldest = today - 8
    lists = DailyLists.new yesterday

    {"ttl" => :turtle, "rdf" => :rdfxml}.each_pair do |suffix, format|
      {"filed" => lists.to_filed_rdf,
        "published" => lists.to_pub_rdf}.each_pair do |name, rdf|
        output = RDF::Writer.for(format).buffer do |writer|
          writer << rdf
        end

        # Write to memcache
        @cache.set "#{yesterday}_#{name}_#{suffix}", output

        # Drop oldest from memcache
        @cache.remove "#{oldest}_#{name}_#{suffix}"
      end
    end
  end

  def get_published suffix, date
    @cache.get "#{date}_published_#{suffix}"
  end

  def get_filed suffix, date
    @cache.get "#{date}_filed_#{suffix}"
  end

end

