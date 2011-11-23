require "json"

class CiteProc

  def initialize record
    @record = record
  end

  def issued
    date_parts = []
    date_parts << @record.publication_year if @record.publication_year
    date_parts << @record.publication_month if @record.publication_month
    date_parts << @record.publication_day if @record.publication_day

    {:"date-parts" => [date_parts]}
  end

  def author
    @record.contributors.map do |contributor|
      c = {:family => contributor.surname}
      c[:given] = contributor.given_name if contributor.given_name
      c
    end
  end

  def page
    if @record.first_page && @record.last_page
      @record.first_page + "-" + @record.last_page
    elsif @record.first_page
      @record.first_page
    else
      nil
    end
  end

  def as_json
    data = {
      :volume => @record.volume,
      :issue => @record.issue,
      :DOI => @record.doi,
      :ISBN => @record.isbn,
      :title => @record.title,
      :"container-title" => @record.publication_title,
      :publisher => @record.publisher_name,
      :issued => issued,
      :author => author,
      :page => page,
      :issn => @record.preferred_issn
    }

    data[:type] = case @record.publication_type
                  when :journal then "article-journal"
                  when :conference then "paper-conference"
                  when :report then "report"
                  when :dissertation then "thesis"
                  when :book then "book"
                  else
                    "article"
                  end
    
    data.each_pair do |k,v|
      if v.nil?
        # Remove items that aren't present in the CrossRef record.
        data.delete k
      end
    end

    data.to_json
  end
     
end
