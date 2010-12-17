class MyCustomError < StandardError
  attr_accessor :status
  def initialize
    @status = 500
    super("Example was unable to do something is was supposed to")
  end
end

class InvalidDOI < StandardError
  attr_accessor :status
  def initialize
    @status = 500
    super("Invalid DOI")
  end
end

not_found do    
  erb :not_found
end

error MyCustomError do
  erb :custom_error, :locals => { :error_message =>  request.env['sinatra.error'].message }
end

error InvalidDOI do
  erb :invalid_doi, :locals => { :error_message =>  request.env['sinatra.error'].message }
end