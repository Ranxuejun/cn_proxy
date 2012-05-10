class CrossrefMetadataRis

  def self.from_record record
    pairs = []

    add_type_to pairs, record
    add_authors_to pairs, record
    add_serials_to pairs, record

    add_to pairs, "TI", record.title
    add_to pairs, "SP", record.first_page
    add_to pairs, "EP", record.last_page
    add_to pairs, "VL", record.volume
    add_to pairs, "PB", record.publisher_name
    add_to pairs, "DO", record.doi
    add_to pairs, "PY", record.publication_year

    pairs.map { |k, v| "#{k}  - #{v}" }.join("\r\n") + "\r\nER  - \r\n"
  end

  def self.add_to pairs, key, val
    unless val.nil? || val.to_s.empty?
      pairs << [key, val.to_s]
    end
  end

  def self.add_type_to pairs, record
    case record.publication_type
    when :journal
      add_to pairs, "TY", "JOUR"
      add_to pairs, "JO", record.publication_title
    when :conference
      add_to pairs, "TY", "CONF"
    when :book
      add_to pairs, "TY", "BOOK"
    when :report
      add_to pairs, "TY", "RPRT"
    when :standard
      add_to pairs, "TY", "STAND"
    when :dissertation
      add_to pairs, "TY", "THES"
    when :database
      add_to pairs, "TY", "DBASE"
    end
  end

  def self.add_authors_to pairs, record
    record.contributors.each do |c|
      add_to pairs, "AU", c.name
    end
  end

  def self.add_serials_to pairs, record
    add_to pairs, "SN", record.isbn if record.isbn
    add_to pairs, "SN", record.preferred_issn if record.preferred_issn
  end

end

