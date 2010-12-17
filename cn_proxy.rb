require 'rubygems'
require 'sinatra'
require 'json'
$LOAD_PATH.unshift File.join(File.dirname(__FILE__),'lib')
require 'configuration'
require 'helpers'
require 'errors'
require 'example_lib'

get '/error?' do
  raise MyCustomError
end

get '/example/?', :provides => :json do
  ("Hello from Sinatra Skeleton Example".split(" ")).to_json
end

get '/example/?' do
  erb :example
end

