require 'sinatra'
require 'rack'
require 'rack/head'
require './cn_proxy.rb'

use Rack::Head
run Sinatra::Application
