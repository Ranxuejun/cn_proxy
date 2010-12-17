class CrossrefMetadataResults
  
  attr_reader :unixref
  attr_reader :records
  attr_reader :search_terms
  
  def initialize
    @records = []
  end
end