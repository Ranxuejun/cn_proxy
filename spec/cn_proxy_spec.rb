require 'spec_helper.rb'
require 'cn_proxy.rb'
Sinatra::Application.app_file = File.join(File.dirname(__FILE__), '..', 'cn_proxy.rb')

describe "Example" do

  include Rack::Test::Methods

  def app
    @app ||= Sinatra::Application
  end
  
  it "Returns 404s" do
    get '/doesnotexist'
    last_response.status.should == 404
    last_response.headers['Content-Type'].should == 'text/html;charset=utf-8'
    last_response.body.should include 'This is nowhere to be found.'
  end
  
  it "Shows custom application error page" do
    get '/error'
    last_response.status.should == 500
    last_response.headers['Content-Type'].should == 'text/html;charset=utf-8'
    last_response.body.should include 'Example was unable to do something is was supposed to'
  end
  
  it "Returns HTML" do
    get '/example'
    last_response.status.should == 200
    last_response.headers['Content-Type'].should == 'text/html;charset=utf-8'
    last_response.body.should include 'Hello from Sinatra Skeleton Example'
  end
   
  it "Returns JSON" do
    get '/example', {}, {'HTTP_ACCEPT' => 'application/json'} 
    last_response.status.should == 200
    last_response.headers['Content-Type'].should == 'application/json' 
    last_response.body.should include "[\"Hello\",\"from\",\"Sinatra\",\"Skeleton\",\"Example\"]"
  end
   
end
