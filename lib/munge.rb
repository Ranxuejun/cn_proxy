require 'nokogiri'
require 'uri'

class Munge

  ELSEVIER_DOMAIN_RE = /linkinghub\.elsevier\.com/
  PLOS_DOMAIN_RE = /www\.plos.+\.org\/article/

  ELSEVIER_RES_PREFIX = 'http://api.elsevier.com/content/article/DOI:'
  ONE_RES_PREFIX = 'http://www.plosone.org/article/fetchObjectAttachment.action?uri='
  BIO_RES_PREFIX = 'http://www.plosbiology.org/article/fetchObjectAttachment.action?uri='

  PLOS_BIO_PART = /journal\.pbio/
  PLOS_ONE_PART = /journal\.pone/

  ELSEVIER_UNIXREF_COMMENT = 'The "apikey" attribute on these URIs is an Elsevier API key used to trigger a check for Prospect headers. It is not a Prospect API Token.'
  ELSEVIER_RDF_COMMENT = 'The "apikey" attribute on the Link URIs is an Elsevier API key used to trigger a check for Prospect headers. It is not a Prospect API Token.'

  ELSEVIER_PREFIX = /\A10\.1016/
  
  def self.munge? unixref_doc
    resource = unixref_doc.at_xpath('//doi_data/resource').text
    puts resource
    if resource.match(ELSEVIER_DOMAIN_RE)
      :elsevier
    elsif resource.match(PLOS_BIO_PART)
      :plos_bio
    elsif resource.match(PLOS_ONE_PART)
      :plos_one
    else
      false
    end
  end

  def self.make_item doc, type, url
    item = Nokogiri::XML::Node.new('item', doc)
    resource = Nokogiri::XML::Node.new('resource', doc)
    resource['mime_type'] = type unless type == :untyped
    resource.add_child(Nokogiri::XML::Text.new(url, doc))
    item.add_child(resource)
    item
  end

  def self.make_collection doc
    collection = Nokogiri::XML::Node.new('collection', doc)
    collection['property'] = 'text-mining'
    collection
  end

  def self.munge_unixref unixref
    munge_doc(Nokogiri::XML(unixref)).to_xml(:indent => 2)
  end

  def self.munge_doc unixref_doc
    doi_data = unixref_doc.at_xpath('//doi_data')
    doi = unixref_doc.at_xpath('//doi_data/doi').text

    puts munge?(unixref_doc)
    case munge?(unixref_doc)
    when :elsevier
      base_url = "#{ELSEVIER_RES_PREFIX}#{doi}?apikey=48f668647fde5c80c46e10215a091781"
      xml_url = "#{base_url}&httpAccept=text/xml"
      plain_url = "#{base_url}&httpAccept=text/plain"
      collection = make_collection(unixref_doc)
      collection.add_child(Nokogiri::XML::Comment.new(unixref_doc, ELSEVIER_UNIXREF_COMMENT))
      collection.add_child(make_item(unixref_doc, :untyped, base_url))
      collection.add_child(make_item(unixref_doc, 'text/xml', xml_url))
      collection.add_child(make_item(unixref_doc, 'text/plain', plain_url))
      doi_data.add_child(collection)
    when :plos_one, :plos_bio
      encoded_doi = URI.encode("info:doi/#{doi}")

      base_url = if doi.match(PLOS_BIO_PART)
                   "#{ONE_RES_PREFIX}#{encoded_doi}"
                 else
                   "#{BIO_RES_PREFIX}#{encoded_doi}"
                 end
      
      xml_url = "#{base_url}&representation=XML"
      pdf_url = "#{base_url}&representation=PDF"

      collection = make_collection(unixref_doc)
      collection.add_child(make_item(unixref_doc, 'text/xml', xml_url))
      collection.add_child(make_item(unixref_doc, 'application/pdf', pdf_url))
      doi_data.add_child(collection)
    end
    unixref_doc
  end

  def self.munge_rdf_output writer, doi
    if doi.match(ELSEVIER_PREFIX)
      writer.write_comment(ELSEVIER_RDF_COMMENT)
    end
  end

end
