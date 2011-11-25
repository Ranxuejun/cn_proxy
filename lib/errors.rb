class MalformedIdentifier < StandardError; end

class UnknownIdentifier < StandardError; end

class UnknownContentType < StandardError; end

class QueryFailure < StandardError; end
class QueryTimeout < StandardError; end

class MalformedDoi < MalformedIdentifier; end
class MalformedIssn < MalformedIdentifier; end
class MalformedIsbn < MalformedIdentifier; end
class MalformedContributor < MalformedIdentifier; end

class UnknownDoi < UnknownIdentifier; end
class UnknownIssn < UnknownIdentifier; end
class UnknownIsbn < UnknownIdentifier; end
class UnknownContributor < UnknownIdentifier; end

class UnknownStyle < UnknownContentType; end
class UnknownLocale < UnknownContentType; end
class UnknownFormat < UnknownContentType; end

def e details
  status details[:status] if details.has_key? :status
  content_type 'text/html'
  details[:msg] if details.has_key? :msg
end

error MalformedIdentifier do
  e :status => 400
end

error MalformedDoi do
  e :status => 400, :msg => "Malformed DOI"
end

error MalformedIssn do
  e :status => 400, :msg => "Malformed ISSN"
end

error MalformedIsbn do
  e :status => 400, :msg => "Malformed ISBN"
end

error MalformedContributor do
  e :status => 400, :msg => "Malformed ID"
end

error UnknownIdentifier do
  e :status => 404
end

error UnknownDoi do
  e :status => 404, :msg => "Unknown DOI"
end

error UnknownIssn do
  e :status => 404, :msg => "Unknown ISSN"
end

error UnknownIsbn do
  e :status => 404, :msg => "Unknown ISBN"
end

error UnknownContributor do
  e :status => 404, :msg => "Unknown ID"
end

error UnknownContentType do
  e :status => 406, 
    :msg => "Can't respond with requested content type"
end

error UnknownStyle do
  e :status => 406,
    :msg => "Unknown style. Please see https://github.com/citation-style-language/styles for a list of styles."
end

error UnknownFormat do
  e :status => 406,
    :msg => "Unknown format. Must be one of rtf, html or text."
end

error UnknownLocale do
  e :status => 406,
    :msg => "Unknown locale. Please see https://github.com/citation-style-language/locales for a list of locales."
end

error QueryFailure do
  e :status => 502, 
    :msg => "Upstream server returned an invalid response"
end

error QueryTimeout do
  e :status => 504,
    :msg => "Upstream server did not respond with a timely response"
end

