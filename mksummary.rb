#!/usr/bin/env ruby

require 'pp'
require 'digest'
require 'optparse' # For command line parsing
require 'yaml'
require 'digest'
require_relative 'lib/resultnode.rb'

$opt = {}
global = OptionParser.new do |opts|

  opts.banner = "Usage: #{$0} <templates>"

  opts.on("-s", "--output <file>", "Output JSON status to file") do |file|
    $opt[:output] = file
  end

end.order!

topRes = ResultNode.new('flash-images', "OK", { } )

%w(ecos linstax redboot).each do |n|
  v = "COPYARTIFACT_BUILD_NUMBER_" + n.upcase
  topRes.meta["#{n}-build"] = ENV[v] if ENV[v]
end

ARGV.each do |template|
  t = YAML::load_file(template)
  stem = File.basename(template, '.txt')
  imgRes = ResultNode.new(stem, "OK", { } )
  binfile = "images/#{stem}.bin"
  if File.exist?(binfile)
    imgRes.meta["md5"] = Digest::MD5.file binfile
  else
    imgRes.status = "Failure"
  end
  imgRes.meta["has-ecos"] = true if t.any? { |e| e['datafile'] && e['datafile'].match(/.gz/) }
  imgRes.meta["has-linux"] = true if t.any? { |e| e['datafile'] && e['datafile'].match(/.mfi/) }
  topRes.addSibling(imgRes)
end

if $opt[:output]
  topRes.to_file($opt[:output])
else
  puts topRes.to_json();
end
