class CrossrefMetadataRdf

  @prism = RDF::Vocabulary.new 'http://prismstandard.org/namespaces/basic/2.0/'
  @bibo = RDF::Vocabulary.new 'http://purl.org/ontology/bibo/'

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
      graph << [id, @prism.doi, record.doi]
      graph << [id, @bibo.doi, record.doi]
      graph << [id, RDF::DC.date, record.publication_date]
      graph << [id, @bibo.volume, record.volume]
      graph << [id, @prism.volume, record.volume]
      graph << [id, @bibo.number, record.edition_number]
      graph << [id, @prism.number, record.edition_number]
      graph << [id, @bibo.pageStart, record.first_page]
      graph << [id, @bibo.pageEnd, record.last_page]
      graph << [id, @prism.startingPage, record.first_page]
      graph << [id, @prism.endingPage, record.last_page]
      graph << [id, RDF::DC.title, record.title]
    
      # We record the type of the main object, and also note the isbn
      # for books. For proceedings the isbn is attached to the container
      # subject.
      
      case record.publication_type
      when :journal then graph << [id, RDF::RDF.type, @bibo.AcademicArticle]
      when :conference then graph << [id, RDF::RDF.type, @bibo.Article]
      when :book then {
          graph << [id, RDF::RDF.type, @bibo.Book]
          graph << [id, @bibo.isbn, record.isbn]
          graph << [id, @prism.isbn, record.isbn]
        }
      when :report then graph << [id, RDF::RDF.type, @bibo.Report]
      when :standard then graph << [id, RDF::RDF.type, @bibo.Standard]
      when :dissertation then graph << [id, RDF::RDF.type, @bibo.Thesis]
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
        graph << [pub_id, @bibo.issn, record.pissn]
        graph << [pub_id, @bibo.eissn, record.eissn]
        graph << [pub_id, @prism.issn, record.pissn]
        graph << [pub_id, @prism.eIssn, record.eissn]
        graph << [pub_id, @bibo.isbn, record.isbn]
        graph << [pub_id, @prism.isbn, record.isbn]
        
        case record.publication_type
        when :journal then graph << [pub_id, RDF::RDF.type, @bibo.Journal]
        when :conference then graph << [pub_id, RDF::RDF.type, @bibo.Proceedings]
        end
      end

      # We describe each contributor and attach them to the doi subject.
      
      record.contributors.each do |c|
        c_id = RDF::URI.new('http://crossref.org/' + record.contributor_path(c))
        
        graph << [id, RDF::DC.creator, c_id]
        
      graph << [c_id, RDF::FOAF.name, c.name]
        graph << [c_id, RDF::FOAF.givenName, c.given_name]
        graph << [c_id, RDF::FOAF.surname, c.surname]
        graph << [c_id, RDF::RDF.type, RDF::FOAF.Person]
      end
      
    end
  end
  
end
