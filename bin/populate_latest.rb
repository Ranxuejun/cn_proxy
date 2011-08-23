#!/usr/bin/env ruby
require "date"
require_relative "../lib/crossref_latest"

options = {}
options[:from] = Date.today - ARGV.first.to_i unless ARGV.empty?
Latest.bootstrap Date.today, options

