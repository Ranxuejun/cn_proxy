require "json"
require "execjs"
require "uri"

class CiteProc

  @@styles = {}
  @@locales = {}

  def initialize record, settings
    @record = record
    @settings = settings

    ExecJS.runtime = ExecJS::Runtimes::SpiderMonkey
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
    as_data.to_json
  end

  def as_data
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

    data
  end

  def load_locale locale
    # TODO check for unknown locale / style
    @@locales[locale] ||= File.open(@settings.locales[locale], "r").read
  end

  def load_style style
    @@styles[style] ||= File.open(@settings.styles[style], "r").read
  end

  def as_style opts={}
    options = {:style => "apa", :locale => "en-US", :id => "1"}.merge(opts)

    style_data = load_style options[:style]
    locale_data = load_locale options[:locale]
    bib_data = as_data
    bib_data["id"] = options[:id]

    source = open(@settings.xmle4xjs).read + "\n" + open(@settings.citeprocjs).read
     source += "\n" + <<-JS
     var style = #{style_data.to_json};
     var locale = #{locale_data.to_json};
     var item = #{bib_data.to_json};
     var sys = {};
     sys.retrieveItem = function(id) { return item };
     sys.retrieveLocale = function(id) { return locale };
     var cluster = {"citationItems": [ {id: "#{options[:id]}"} ], "properties": {"noteIndex": 1}};
     var citeProc = new CSL.Engine(sys, style);
     citeProc.appendCitationCluster(cluster);
     citeProc.setOutputFormat("text");
     var result = citeProc.makeBibliography()["#{options[:id]}"][0];
     result = escape(result);
     JS
    
    cxt = ExecJS.compile(source)

    unescaped = URI.unescape(cxt.eval("result"))
    unescaped.gsub(/%u(\d\d\d\d)/) {|m| [$1].pack("H*").unpack("n*").pack("U*")}
  end
     
end
