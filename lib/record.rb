# -*- coding: utf-8 -*-
require 'nokogiri'
require 'unidecode'
require 'digest/md5'
require 'net/http'

require_relative 'rdf'

class Record

  attr_reader :contributors

  class Contributor

    attr_writer :ordinal

    def initialize node
      @xml = node
    end

    def sequence
      return @xml['sequence'] if @xml['sequence']
    end

    def contributor_role
      return @xml['contributor_role'] if @xml['contributor_role']
    end

    def surname
      return @xml.at_xpath("surname").text if @xml.at_xpath("surname")
    end

    def given_name
      return @xml.at_xpath("given_name").text if @xml.at_xpath("given_name")
    end

    def name
      if @xml.at_xpath('given_name') then
        @xml.at_xpath('given_name').text + ' ' + @xml.at_xpath('surname').text
      else
        @xml.at_xpath('surname').text
      end
    end

    def slug
      decoded = Unidecoder.decode name.strip
      decrufted = decoded.gsub(/\./, ' ').gsub(/\s+/, '-').downcase
      normalised = decrufted.gsub(/[^a-z-]/, '')
      normalised.gsub(/\-+/, "-").gsub(/\-+\Z/, "").gsub(/\A-+/, "")
    end

    def unique_slug
      if @ordinal and @ordinal != 0 then
        slug + '-' + @ordinal.to_s
      else
        slug
      end
    end
  end

  def initialize record
    @record=record.root
    add_contributors
  end

  def owner_prefix
    return @record.at_xpath("//doi_record")['owner']
  end

  def publication_type
    return :journal if @record.at_xpath("//journal")
    return :book if @record.at_xpath("//book")
    return :dissertation if @record.at_xpath("//dissertation")
    return :conference if @record.at_xpath("//conference")
    return :report if @record.at_xpath("//report-paper")
    return :standard if @record.at_xpath("//standard")
    return :database if @record.at_xpath("//database")
    return :component if @record.at_xpath("//sa_component")
    return :unknown
  end

  def bibo_things
    case publication_type
    when :journal then {
        :component => "bibo:AcademicArticle",
        :container => "bibo:Journal",
        :container_id => "urn:issn:#{preferred_issn}"
      }
    when :conference then {
        :component => "bibo:Article",
        :container => "bibo:Proceedings",
        :container_id => "urn:isbn:#{isbn}"
      }
    when :report then {
        :component => "bibo:Report"
      }
    when :standard then {
        :component => "bibo:Standard"
      }
    when :dissertation then {
        :component => "bibo:Thesis"
      }
    when :database then {
        :component => "owl:Thing"
      }
    when :book then {
        :component => "bibo:Book"
      }
    else {}
    end
  end

  def maybe_text paths
    if paths.is_a?(Array)
      texts = paths.map do |path| 
        element = @record.at_xpath(path)
        element.text if element
      end

      texts.compact.first
    else
      element = @record.at_xpath(paths)
      element.text if element
    end
  end

  def doi
    return @record.xpath('//doi_data/doi').last.text
  end

  def publication_title
    maybe_text '//full_title' or maybe_text '//proceedings_title'
  end

  def title
    maybe_text '//titles/title'
  end

  def subtitle
    maybe_text '//subtitle'
  end

  def eissn
    return issn_of_type 'electronic'
  end

  def pissn
    return issn_of_type 'print'
  end

  def preferred_issn
    return (pissn and not pissn.empty?) ? pissn : eissn
  end

  def isbn
    maybe_text ['//book_metadata/isbn', 
                '//dissertation/isbn', 
                '//proceedings_metadata/isbn', 
                '//report-paper_metadata/isbn', 
                '//series_metadata/isbn', 
                '//standard_metadata/isbn']
  end

  def volume
    maybe_text '//journal_volume/volume'
  end

  # Unused in templates
  def issue
    maybe_text '//journal_issue/issue'
  end

  def edition_number
    maybe_text ['//book_metadata/edition_number', 
                '//report-paper_metadata/edition_number', 
                '//standard_metadata/edition_number']
  end

  def first_page
    maybe_text '//pages/first_page'
  end

  def last_page
    maybe_text '//pages/last_page'
  end

  def publication_year
    return  @record.at_xpath("//publication_date/year").text.to_i if @record.at_xpath("//publication_date/year")
  end

  def publication_month
    return  @record.at_xpath("//publication_date/month").text.to_i if  @record.at_xpath("//publication_date/month")
  end

  def publication_day
    return  @record.at_xpath("//publication_date/day").text.to_i if @record.at_xpath("//publication_date/day")
  end

  def publication_date
    return (publication_day and publication_month) ? "#{publication_year}-#{publication_month}-#{publication_day}" : "#{publication_year}"
  end

  def publisher_identifiers
    @record.xpath('//publisher_item/identifier').map do |identifier|
      {:type => identifier[:id_type], :id => identifier.text}
    end
  end

  def publisher_item_numbers
    @record.xpath('//publisher_item/item_number').map do |item_number|
      item_number.text
    end
  end

  # Unused in templates
  def url
    return @record.at_xpath("//resource").text if @format == :unixref
  end

  def publisher_name
    if owner_prefix.nil?
      nil
    else
      lookup_publisher unless @publisher
      @publisher.at_xpath("//publisher_name").text if @publisher.at_xpath "//publisher_name"
    end
  end

  # Unused in templates
  def publisher_location
    if owner_prefix.nil?
      nil
    else
      lookup_publisher unless @publisher
      @publisher.at_xpath("//publisher_location").text.gsub(/\n/,"") if @publisher.at_xpath "//publisher_location"
    end
  end

  def lookup_publisher
    prefix = owner_prefix

    Net::HTTP.start 'www.crossref.org' do |http|
      http.open_timeout = 30
      http.read_timeout = 30

      begin
        results = http.get "/getPrefixPublisher/?prefix=#{prefix}"

        case results.code.to_i
        when 200 then @publisher = Nokogiri::XML results.body
        when 404 then @publisher = Nokogiri::XML::Document.new
        else
          raise QueryFailure
        end

      rescue TimeoutError => e
        raise QueryTimeout
      end
    end
  end

  def normalise_issn issn
    norm = issn.gsub /[^0-9]+/, ''
    if issn =~ /x|X/ then
      "#{norm[0..3]}-#{norm[4..-1]}X"
    else
      "#{norm[0..3]}-#{norm[4..-1]}"
    end
  end

  def issn_of_type type
    @record.xpath('//journal_metadata/issn').each { |issn|
      if issn['media_type'] == type
        return normalise_issn(issn.text)
      elsif issn['media_type'] == nil and type == 'print'
        return normalise_issn(issn.text)
      end
    }
    return nil
  end

  def add_contributors
    @contributors = Array.new
    @contributor_name_counts = Hash.new
    @record.xpath("//contributors/person_name").each do |contributor_node|
      c = Contributor.new contributor_node

      old_count = @contributor_name_counts[c.slug]

      new_count = @contributor_name_counts[c.slug] += 1 if old_count
      new_count = @contributor_name_counts[c.slug] = 1 if not old_count

      @contributors << c
    end

    temp_counts = Hash.new

    @contributors.each do |c|
      slug = c.slug
      if @contributor_name_counts[slug] != 1 then
        if temp_counts[slug] then
          c.ordinal = temp_counts[slug] = temp_counts[slug].next
        else
          c.ordinal = temp_counts[slug] = 1
        end
      end
    end
  end

  def contributor_id c
    "#{c.unique_slug}-#{Digest::MD5.hexdigest(doi).slice(16, 16).to_i(16).to_s(36)}"
  end

  def maybe_tag name, content
    if content and not content.empty? then
      "<#{name}>#{content}</#{name}>"
    else
      ""
    end
  end

  def full_text_resource
    resource_url = nil

    @record.xpath("//resource").each do |resource_node|
      parent = resource_node.parent
      parent_name = parent.name

      case parent_name
      when 'item'
        # potentially a crawler full-text url
        if parent.attributes.has_key?('crawler')
          resource_url = resource_node.text
        end
      when 'doi_data'
        # standard resolution url, ignore
      end
    end

    resource_url
  end

  def citations
    @citations ||= @record.xpath("//citation_list/citation").map do |citation_node|
      citation_info = {}
      citation_node.children.each do |info|
        name = info.name
        name = 'year' if name == 'cYear'
        citation_info[name.to_sym] = info.text unless name == 'text'
      end
      citation_info
    end
  end

  def contributors_with_role role
    contributors.reject {|c| c.contributor_role != role }
  end

  def authors
    contributors_with_role('author')
  end

  def editors
    contributors_with_role('editor')
  end

  def to_graph
    Rdf.create_for_record self
  end

end
