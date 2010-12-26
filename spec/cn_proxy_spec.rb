require 'spec_helper.rb'
require 'cn_proxy.rb'

Sinatra::Application.app_file = File.join(File.dirname(__FILE__), '..', 'cn_proxy.rb')

describe "Example" do

  include Rack::Test::Methods

  def app
    @app ||= Sinatra::Application
  end

  it "Returns 500" do
    get '/doidoesnotexist'
    last_response.status.should == 500
    last_response.headers['Content-Type'].should == 'text/html;charset=utf-8'
    last_response.body.should include 'Invalid DOI'
  end

  it "/echo_doi/10.1037/0003-066X.59.1.29 using content negotiation for JSON" do
    get '/echo_doi/10.1037/0003-066X.59.1.29', {}, {'HTTP_ACCEPT' => 'application/json'} 
    last_response.status.should == 200
    last_response.headers['Content-Type'].should == 'application/json'
    last_response.body.should == '10.1037/0003-066X.59.1.29' 
  end

  it "/10.1037/0003-066X.59.1.29 using content negotiation for unixref" do
    get '/10.1037/0003-066X.59.1.29', {}, {'HTTP_ACCEPT' => 'application/unixref+xml'} 
    last_response.status.should == 200
    last_response.headers['Content-Type'].should == 'application/unixref+xml'
    last_response.body.should include '10.1037/0003-066X.59.1.29' 
  end

  it "/10.1037/0003-066X.59.1.29 using content negotiation for JSON" do
    get '/10.1037/0003-066X.59.1.29', {}, {'HTTP_ACCEPT' => 'application/json'} 
    last_response.status.should == 200
    last_response.headers['Content-Type'].should == 'application/json'
    last_response.body.should include '10.1037/0003-066X.59.1.29' 
  end

  it "/10.1037/0003-066X.59.1.29 using content negotiation for ATOM" do
    get '/10.1037/0003-066X.59.1.29', {}, {'HTTP_ACCEPT' => 'application/atom+xml'} 
    last_response.status.should == 200
    last_response.headers['Content-Type'].should == 'application/atom+xml'
    last_response.body.should include '10.1037/0003-066X.59.1.29' 
  end

  it "/10.1037/0003-066X.59.1.29 using content negotiation for Turtle" do
    get '/10.1037/0003-066X.59.1.29', {}, {'HTTP_ACCEPT' => 'text/turtle'} 
    last_response.status.should == 200
    last_response.headers['Content-Type'].should == 'text/turtle'
    last_response.body.should include '<info:doi/10.1037/0003-066X.59.1.29>' 
  end
  
  it "/10.1037/0003-066X.59.1.29 using content negotiation for N3" do
    get '/10.1037/0003-066X.59.1.29', {}, {'HTTP_ACCEPT' => 'text/n3'} 
    last_response.status.should == 200
    last_response.headers['Content-Type'].should == 'text/n3'
    last_response.body.should include '<info:doi/10.1037/0003-066X.59.1.29>' 
  end

end
