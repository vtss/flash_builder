#!/usr/bin/env ruby

# Copyright (c) 2016 Microsemi Corporation "Microsemi".

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

jenkins = ENV["JENKINS_URL"]

jobnames = {
  "redboot" => "webstax2-redboot",
  "ecos" => "webstax2-webstax-3_60_mass",
  "linstax" => "webstax2-linstax/4.0-soak",
}

if jenkins
  jobnames.keys.each do |n|
    v = "COPYARTIFACT_BUILD_NUMBER_" + n.upcase
    buildno = ENV[v]
    if buildno
      topRes.meta["#{n}-url"] = "#{jenkins}job/#{jobnames[n]}/#{buildno}"
    end
  end
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
