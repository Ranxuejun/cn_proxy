require 'rdf'

# Old code used for atom feeds
class Results

  attr_reader :unixref
  attr_reader :records
  attr_reader :search_terms

  def initialize
    @records = []
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
