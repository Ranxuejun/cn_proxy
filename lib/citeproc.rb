require "json"
require "uri"
require 'citeproc'

require_relative "errors"

class CiteProcHelper

  @@styles = {}
  @@locales = {}

  def initialize record, settings
    @record = record
    @settings = settings
  end

  def issued
    date_parts = []
    date_parts << @record.publication_year if @record.publication_year
    date_parts << @record.publication_month if @record.publication_month
    date_parts << @record.publication_day if @record.publication_day

    {:"date-parts" => [date_parts]}
  end

  def contributor role
    @record.contributors.reject {|c| c.contributor_role != role }.map do |contributor|
      c = {:family => contributor.surname}
      c[:given] = contributor.given_name if contributor.given_name
      c
    end
  end

  def author
    contributor "author"
  end

  def editor
    contributor "editor"
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
    as_data.to_json
  end

  def as_data
    data = {
      :volume => @record.volume,
      :issue => @record.issue,
      :number => @record.edition_number,
      :DOI => @record.doi,
      :ISBN => @record.isbn,
      :title => @record.title,
      :"container-title" => @record.publication_title,
      :publisher => @record.publisher_name,
      :issued => issued,
      :author => author,
      :editor => editor,
      :page => page
    }

    data[:type] = case @record.publication_type
                  when :journal then "article-journal"
                  when :conference then "paper-conference"
                  when :report then "report"
                  when :dissertation then "thesis"
                  when :book then "book"
                  else
                    "misc"
                  end
    
    data.each_pair do |k,v|
      if v.nil?
        # Remove items that aren't present in the CrossRef record.
        data.delete k
      end
    end

    data
  end

  def load_locale locale
    raise UnknownLocale.new if @settings.locales[locale].nil?
    if @@locales[locale].nil?
      @@locales[locale] = open(@settings.locales[locale]).read
    end
    @@locales[locale]
  end

  def load_style style
    raise UnknownStyle.new if @settings.styles[style].nil?
    if @@styles[style].nil?
      @@styles[style] = open(@settings.styles[style]).read
    end
    @@styles[style]
  end

  def as_style opts={}
    options = {
      :format => "default", # text
      :style => "bibtex",
      :locale => "en-US"
    }.merge(opts)

    raise UnknownFormat unless ["default", "text", "rtf", "html"].include?(options[:format])

    style_data = load_style options[:style]
    locale_data = load_locale options[:locale]
    bib_data = as_data
    bib_data["id"] = 'item'

    ref = CiteProc.process(bib_data,
                           :style => CSL::Style.new(style_data), 
                           :locale => CSL::Locale.new(locale_data),
                           :format => options[:format])

    puts ref

    ref.to_s
  end
     
end

