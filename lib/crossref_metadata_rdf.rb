require 'rdf'

require_relative 'errors'

class CrossrefMetadataRdf

  @@prism = RDF::Vocabulary.new 'http://prismstandard.org/namespaces/basic/2.1/'
  @@bibo = RDF::Vocabulary.new 'http://purl.org/ontology/bibo/'
  @@rdf = RDF::Vocabulary.new 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'

  @@data = 'http://data.crossref.org'
  @@id = 'http://id.crossref.org'
  @@periodicals = 'http://periodicals.dataincubator.org'

  def self.prism
    @@prism
  end

  def self.bibo
    @@bibo
  end

  def self.rdf
    @@rdf
  end

  def self.contributor_res id
    "#{@@id}/contributor/#{id}"
  end

  def self.issue_res issn
    "#{@@id}/issn/#{issn}"
  end

  def self.book_res isbn
    "#{@@id}/isbn/#{isbn}"
  end

  def self.contributor_data id
    "#{@@data}/contributor/#{id}"
  end

  def self.issue_data issn
    "#{@@data}/issn/#{issn}"
  end

  def self.book_data isbn
    "#{@@data}/isbn/#{isbn}"
  end

  def self.issue_urn issn
    "urn:issn:#{issn}"
  end

  def self.book_urn isbn
    "urn:isbn:#{isbn}"
  end

  def self.incubator_issue_res issn
    "#{@@periodicals}/issn/#{issn}"
  end

  def self.add_to graph, statement
    if statement[2] != nil then
      graph << statement
    end
  end

  def self.find_issn_graph issn
    begin
      issn_graph = RDF::Graph.load self.incubator_issue_res(issn) + '.rdf'

      issn_graph.each_object do |object|
        case object.to_s
        when /#{@@periodicals}\/journal\//
          return RDF::Graph.load(object.to_s + '.rdf')
        end
      end
    rescue
      # TODO Make this more granular.
      raise UnknownIssn
    end
  end

  def self.create_for_issn issn
    issn_graph = self.find_issn_graph issn

    RDF::Graph.new do |graph|

      id = RDF::URI.new self.issue_res issn
      urn_id = RDF::URI.new self.issue_urn issn
      di_id = RDF::URI.new self.incubator_issue_res issn

      queries = RDF::Query.new({
        :issue => {
          RDF::DC.title => :title,
          RDF::DC.publisher => :publisher,
          rdf.type => :type
        }
      })

      results = queries.execute issn_graph

      add_to graph, [id, RDF::OWL.sameAs, di_id]
      add_to graph, [id, RDF::OWL.sameAs, urn_id]

      if not results.empty? then
        publisher_res = RDF::URI.new results.first[:publisher].to_s

        add_to graph, [id, RDF::DC.title, results.first[:title].to_s]
        add_to graph, [id, RDF::DC.publisher, publisher_res]
        add_to graph, [id, rdf.type, results.first[:type].to_s]
      end

    end
  end

  def self.create_for_record record
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

      info_doi = RDF::URI.new "info:doi/#{record.doi}"
      doi = RDF::URI.new "doi:#{record.doi}"

      add_to graph, [id, RDF::DC.identifier, record.doi]
      add_to graph, [id, RDF::OWL.sameAs, info_doi]
      add_to graph, [id, RDF::OWL.sameAs, doi]
      add_to graph, [id, prism.doi, record.doi]
      add_to graph, [id, bibo.doi, record.doi]
      add_to graph, [id, RDF::DC.date, pub_date]
      add_to graph, [id, bibo.volume, record.volume]
      add_to graph, [id, prism.volume, record.volume]
      add_to graph, [id, bibo.number, record.edition_number]
      add_to graph, [id, prism.number, record.edition_number]
      add_to graph, [id, bibo.pageStart, record.first_page]
      add_to graph, [id, bibo.pageEnd, record.last_page]
      add_to graph, [id, prism.startingPage, record.firstX_page]
      add_to graph, [id, prism.endingPage, record.last_page]
      add_to graph, [id, RDF::DC.title, record.title]
      add_to graph, [id, RDF::DC.alternative, record.subtitle]
      add_to graph, [id, RDF::DC.publisher, record.publisher_name]

      ft_link = record.full_text_resource
      add_to(graph, [id, RDF::RDFS.value, RDF::URI.new(ft_link)]) unless ft_link.nil?

      # We record the type of the doi subject, and also note the isbn
      # for books. For proceedings the isbn is attached to the container
      # subject.

      case record.publication_type
      when :journal
        graph << [id, rdf.type, bibo.Article]
      when :conference
        graph << [id, rdf.type, bibo.Article]
      when :book
        graph << [id, rdf.type, bibo.Book]
        if record.isbn
          graph << [id, RDF::OWL.sameAs, RDF::URI.new(self.book_urn(record.isbn))]
        end
        add_to graph, [id, bibo.isbn, record.isbn]
        add_to graph, [id, prism.isbn, record.isbn]
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

      preferred_issn = record.preferred_issn

      pub_id = case record.publication_type
               when :journal then self.issue_res preferred_issn
               when :conference then self.book_res record.isbn
               else nil
               end

      if pub_id then
        pub_id = RDF::URI.new pub_id

        add_to graph, [pub_id, RDF::DC.title, record.publication_title]
        add_to graph, [pub_id, bibo.issn, record.pissn]
        add_to graph, [pub_id, bibo.eissn, record.eissn]
        add_to graph, [pub_id, prism.issn, record.pissn]
        add_to graph, [pub_id, prism.eIssn, record.eissn]
        add_to graph, [pub_id, bibo.isbn, record.isbn]
        add_to graph, [pub_id, prism.isbn, record.isbn]

        graph << [id, RDF::DC.isPartOf, pub_id]
        graph << [pub_id, RDF::DC.hasPart, id]

        case record.publication_type
        when :journal
          urn = RDF::URI.new self.issue_urn preferred_issn

          graph << [pub_id, rdf.type, bibo.Journal]
          graph << [pub_id, RDF::OWL.sameAs, urn]
          graph << [pub_id, RDF::DC.identifier, preferred_issn]
        when :conference
          urn = RDF::URI.new self.book_urn record.isbn

          graph << [id, bibo.reproducedIn, pub_id]
          graph << [pub_id, rdf.type, bibo.Proceedings]
          graph << [pub_id, RDF::OWL.sameAs, urn]
          graph << [pub_id, RDF::DC.identifier, record.isbn]
        end
      end

      # We describe each contributor and attach them to the doi subject.

      record.authors.each do |c|
        c_id = RDF::URI.new self.contributor_res(record.contributor_id(c))

        graph << [id, RDF::DC.creator, c_id]

        add_to graph, [c_id, RDF::FOAF.name, c.name]
        add_to graph, [c_id, RDF::FOAF.givenName, c.given_name]
        add_to graph, [c_id, RDF::FOAF.familyName, c.surname]
        add_to graph, [c_id, rdf.type, RDF::FOAF.Person]
      end

    end
  end

end
