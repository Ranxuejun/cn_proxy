require 'rubygems'
require 'rdf'

class CrossrefMetadataRdf

  @@prism = RDF::Vocabulary.new 'http://prismstandard.org/namespaces/basic/2.0/'
  @@bibo = RDF::Vocabulary.new 'http://purl.org/ontology/bibo/'
  @@rdf = RDF::Vocabulary.new 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'

  def self.prism
    @@prism
  end

  def self.bibo
    @@bibo
  end

  def self.rdf
    @@rdf
  end

  def self.add_to graph, statement
    if statement[2] != nil then
      graph << statement
    end
  end

  def self.create_graph record
    RDF::Graph.new do |graph|
      
      # We start by deciding an identifier for the doi subject we are 
      # describing.
      
      id = RDF::URI.new('http://dx.doi.org/' + record.doi)

      # See what we can do with the publication date. If we have all the
      # bits for a full date we'll get some typing in the output.

      pub_date = record.publication_date
      begin
        pub_date = Date.strptime pub_date
      rescue
      end
      
      # We try to record as many predicates about the doi subject as we
      # can, given the unixref available.
      
      add_to graph, [id, RDF::DC.identifier, RDF::URI.new(record.doi)]
      add_to graph, [id, RDF::OWL.sameAs, RDF::URI.new('info:doi/' + record.doi)]
      add_to graph, [id, RDF::OWL.sameAs, RDF::URI.new('doi:' + record.doi)]
      add_to graph, [id, prism.doi, record.doi]
      add_to graph, [id, bibo.doi, record.doi]
      add_to graph, [id, RDF::DC.date, pub_date]
      add_to graph, [id, bibo.volume, record.volume]
      add_to graph, [id, prism.volume, record.volume]
      add_to graph, [id, bibo.number, record.edition_number]
      add_to graph, [id, prism.number, record.edition_number]
      add_to graph, [id, bibo.pageStart, record.first_page]
      add_to graph, [id, bibo.pageEnd, record.last_page]
      add_to graph, [id, prism.startingPage, record.first_page]
      add_to graph, [id, prism.endingPage, record.last_page]
      add_to graph, [id, RDF::DC.title, record.title]
    
      # We record the type of the doi subject, and also note the isbn
      # for books. For proceedings the isbn is attached to the container
      # subject.
      
      case record.publication_type
      when :journal
        graph << [id, rdf.type, bibo.AcademicArticle]
      when :conference
        graph << [id, rdf.type, bibo.Article]
      when :book
          graph << [id, rdf.type, bibo.Book]
          graph << [id, bibo.isbn, record.isbn]
          graph << [id, prism.isbn, record.isbn]
      when :report
        graph << [id, rdf.type, bibo.Report]
      when :standard
        graph << [id, rdf.type, bibo.Standard]
      when :dissertation
        graph << [id, rdf.type, bibo.Thesis]
      when :database
        graph << [id, rdf.type, RDF::OWL.Thing]
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
        
        add_to graph, [pub_id, RDF::DC.title, record.publication_title]
        add_to graph, [pub_id, bibo.issn, record.pissn]
        add_to graph, [pub_id, bibo.eissn, record.eissn]
        add_to graph, [pub_id, prism.issn, record.pissn]
        add_to graph, [pub_id, prism.eIssn, record.eissn]
        add_to graph, [pub_id, bibo.isbn, record.isbn]
        add_to graph, [pub_id, prism.isbn, record.isbn]
        
        case record.publication_type
        when :journal then graph << [pub_id, rdf.type, bibo.Journal]
        when :conference then graph << [pub_id, rdf.type, bibo.Proceedings]
        end
      end

      # We describe each contributor and attach them to the doi subject.
      
      record.contributors.each do |c|
        c_id = RDF::URI.new('http://crossref.org/' + record.contributor_path(c))
        
        graph << [id, RDF::DC.creator, c_id]
        
        add_to graph, [c_id, RDF::FOAF.name, c.name]
        add_to graph, [c_id, RDF::FOAF.givenName, c.given_name]
        add_to graph, [c_id, RDF::FOAF.familyName, c.surname]
        add_to graph, [c_id, rdf.type, RDF::FOAF.Person]
      end
      
    end
  end
  
end
