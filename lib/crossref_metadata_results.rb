require 'rubygems'
require 'rdf'

# Note this class is just stubbed-out becaue, in the future (e.g. for OpenSearch)
# we will want ability to return numerous DOI records using content-negotiation
class CrossrefMetadataResults
  
  attr_reader :unixref
  attr_reader :records
  attr_reader :search_terms
  
  def initialize 
    @records = []
  end
  
  def ninitialize dois
    @records = []
    dois.each do |doi| 
    end   
  end

  def to_graph
    RDF::Graph.new do |graph|
      @records.each do |record|
        record.to_graph.each_statement do |statement|
          graph << statement
        end
      end
    end
  end

end
