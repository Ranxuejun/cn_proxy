class MalformedIdentifier < StandardError; end

class UnknownIdentifier < StandardError; end

class UnknownContentType < StandardError; end

class QueryFailure < StandardError; end

class MalformedDoi < MalformedIdentifier; end
class MalformedIssn < MalformedIdentifier; end
class MalformedIsbn < MalformedIdentifier; end
class MalformedContributor < MalformedIdentifier; end

class UnknownDoi < UnknownIdentifier; end
class UnknownIssn < UnknownIdentifier; end
class UnknownIsbn < UnknownIdentifier; end
class UnknownContributor < UnknownIdentifier; end

error MalformedIdentifier do
  status 400
end

error MalformedDoi do
  status 400
  "Malformed DOI"
end

error MalformedIssn do
  status 400
  "Malformed Issn"
end

error MalformedIsbn do
  status 400
  "Malformed Isbn"
end

error MalformedContributor do
  status 400
  "Malformed contributor ID"
end

error UnknownIdentifier do
  status 404
end

error UnknownDoi do
  status 404
  "Unknown DOI"
end

error UnknownIssn do
  status 404
  "Unknown Issn"
end

error UnknownIsbn do
  status 404
  "Unknown Isbn"
end

error UnknownContributor do
  status 404
  "Unknown contributor ID"
end

error UnknownContentType do
  status 406
  "Can't respond with requested content type"
end

error QueryFailure do
  status 500
  "An external query failed"
end

