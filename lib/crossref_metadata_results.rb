# Note this class is just stubbed-out becaue, in the future (e.g. for OpenSearch)
# we will want ability to return numerous DOI records using content-negotiation
class CrossrefMetadataResults
  
  attr_reader :unixref
  attr_reader :records
  attr_reader :search_terms
  
  def initialize
    @records = []
  end
end