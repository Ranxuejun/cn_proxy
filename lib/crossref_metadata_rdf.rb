
def create_graph record
  RDF::Graph.new do |graph|

    # We start by deciding an identifier for the main subject we are 
    # describing.

    id = RDF::URI.new('http://dx.doi.org/' + record.doi)

    # We try to record as many predicates about the main subject as we
    # can given the unixref available.

    graph << [id, RDF::DC.identifier, RDF::URI.new(record.doi)]
    graph << [id, RDF::OWL.sameAs, RDF::URI.new('info:doi/' + record.doi)]
    graph << [id, RDF::OWL.sameAs, RDF::URI.new('doi:' + record.doi)]
    graph << [id, RDF::PRISM.doi, record.doi]
    graph << [id, RDF::BIBO.doi, record.doi]
    graph << [id, RDF::DC.date, record.publication_date]
    graph << [id, RDF::BIBO.volume, record.volume]
    graph << [id, RDF::PRISM.volume, record.volume]
    graph << [id, RDF::BIBO.number, record.edition_number]
    graph << [id, RDF::PRISM.number, record.edition_number]
    graph << [id, RDF::BIBO.pageStart, record.first_page]
    graph << [id, RDF::BIBO.pageEnd, record.last_page]
    graph << [id, RDF::PRISM.startingPage, record.first_page]
    graph << [id, RDF::PRISM.endingPage, record.last_page]
    graph << [id, RDF::DC.title, record.title]
    
    # We record the type of the main object, and also note the isbn
    # for books. For proceedings the isbn is attached to the container
    # subject.

    case record.publication_type
    when :journal then graph << [id, RDF::RDF.type, RDF::BIBO.AcademicArticle]
    when :conference then graph << [id, RDF::RDF.type, RDF::BIBO.Article]
    when :book then {
        graph << [id, RDF::RDF.type, RDF::BIBO.Book]
        graph << [id, RDF::BIBO.isbn, record.isbn]
        graph << [id, RDF::PRISM.isbn, record.isbn]
      }
    when :report then graph << [id, RDF::RDF.type, RDF::BIBO.Report]
    when :standard then graph << [id, RDF::RDF.type, RDF::BIBO.Standard]
    when :dissertation then graph << [id, RDF::RDF.type, RDF::BIBO.Thesis]
    when :database then graph << [id, RDF::RDF.type, RDF::OWL.Thing]
    end

    # With conference proceedings and journals, we need to describe them as
    # well as the doi/article.

    pub_id = case record.publication_type
             when :journal then "urn:issn:#{record.preferred_issn}"
             when :conference then "urn:isbn:#{record.isbn}"
             else nil
             end

    if pub_id then
      pub_id = RDF::URI.new pub_id
      
      graph << [id, RDF::DC.isPartOf, pub_id]

      graph << [pub_id, RDF::DC.title, record.publication_title]
      graph << [pub_id, RDF::BIBO.issn, record.pissn]
      graph << [pub_id, RDF::BIBO.eissn, record.eissn]
      graph << [pub_id, RDF::PRISM.issn, record.pissn]
      graph << [pub_id, RDF::PRISM.eIssn, record.eissn]
      graph << [pub_id, RDF::BIBO.isbn, record.isbn]
      graph << [pub_id, RDF::PRISM.isbn, record.isbn]
      
      case record.publication_type
      when :journal then graph << [pub_id, RDF::RDF.type, RDF::BIBO.Journal]
      when :conference then graph << [pub_id, RDF::RDF.type, RDF::BIBO.Proceedings]
      end
    end

    # We describe each contributor and attach them to the doi subject.
    
    

  end
end
