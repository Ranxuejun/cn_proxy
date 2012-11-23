require 'json'

class CrossrefMetadataBibJson

  def self.from_record record
    data = {
      :title => record.title,
      :author => record.contributors.map { |c| {:name => c.name } },
      :year => record.publication_year,
      :month => record.publication_month,
      :url => "http://dx.doi.org/#{record.doi}",
      :identifier => [{
          :type => :doi,
          :id => record.doi,
          :url => "http://dx.doi.org/#{record.doi}"
        }]
    }

    case record.publication_type
    when :journal
      data[:type] = :article
      add_journal data, record
    when :conference
      data[:type] = :inproceedings
    when :book
      data[:type] = :book
    when :report
    when :standard
    when :dissertation
    when :database
    end

    data.reject! { |k, v| v.nil? || v.empty? }

    data.to_json
  end

  def self.add_journal data, record
    issns = [
      {
        :id => record.preferred_issn,
        :type => :issn
      },
      {
        :id => record.p_issn,
        :type => :print_issn
      },
      {
        :id => record.e_issn,
        :type => :electronic_issn
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
      :pages => pages
    }

    journal.reject! { |k, v| v.nil? || v.empty? }

    journal
  end

end
