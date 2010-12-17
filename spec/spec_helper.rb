require 'rubygems'
require 'sinatra'
require 'rack/test'
require 'rspec'
require 'rspec/autorun'
require 'rspec/expectations'
$LOAD_PATH.unshift File.join(File.dirname(__FILE__),'..')
$LOAD_PATH.unshift File.join(File.dirname(__FILE__),'..','lib')


set :environment, :test
set :run, false
set :raise_errors, true
set :logging, false
