require 'json'

class CrossrefMetadataBibJson

  def self.from_record record
    data = {
      :title => record.title,
      :author => record.authors.map { |c| {:name => c.name} },
      :year => record.publication_year,
      :month => record.publication_month,
      :citation => citation_data(record),
      :link => {:url => "http://dx.doi.org/#{record.doi}"},
      :item_number => record.publisher_item_numbers,
      :identifier => [{
          :type => :doi,
          :id => record.doi
        }]
    }

    data[:year] = record.publication_year.to_s if record.publication_year
    data[:month] = record.publication_month.to_s if record.publication_month
    data[:day] = record.publication_day.to_s if record.publication_day

    record.publisher_identifiers.each do |id|
      data[:identifier] << id
    end

    if record.full_text_resource
      data[:full_text] = {:url => record.full_text_resource}
    end

    case record.publication_type
    when :journal
      data[:type] = :article
      data[:journal] = journal_data(record)
    when :conference
      data[:type] = :inproceedings
    when :book
      data[:type] = :book
    when :report
    when :standard
    when :dissertation
    when :database
    end

    data.reject! { |k, v| v.nil? || ((v.class == Hash || v.class == Array) && v.empty?) }

    JSON.pretty_generate data
  end

  def self.citation_data record
    record.citations.map do |citation|
      doi = citation[:doi]
      citation.delete(:doi)
      if doi
        citation.merge({:identifier => {:type => :doi, :id => doi}})
      else
        citation
      end
    end
  end

  def self.journal_data record
    issns = [
      {
        :id => record.preferred_issn,
        :type => :issn
      },
      {
        :id => record.pissn,
        :type => :pissn
      },
      {
        :id => record.eissn,
        :type => :eissn
      }
    ]

    issns.reject! { |issn| issn[:id].nil? || issn[:id].empty? }

    pages = ""
    pages << "#{record.first_page}" if record.first_page
    pages << "-#{record.last_page}" if record.last_page

    journal = {
      :name => record.publication_title,
      :identifier => issns,
      :volume => record.volume,
      :issue => record.issue,
      :pages => pages,
      :first_page => record.first_page,
      :last_page => record.last_page
    }

    journal.reject! { |k, v| v.nil? || ((v.class == Hash || v.class == Array) && v.empty?) }

    journal
  end

end
