#!/usr/bin/env ruby
# Copyright (c) 2006-2017 Microsemi Corporation "Microsemi". All Rights Reserved.
#
# Unpublished rights reserved under the copyright laws of the United States of
# America, other countries and international treaties. Permission to use, copy,
# store and modify, the software and its source code is granted but only in
# connection with products utilizing the Microsemi switch and PHY products.
# Permission is also granted for you to integrate into other products, disclose,
# transmit and distribute the software only in an absolute machine readable
# format (e.g. HEX file) and only in or with products utilizing the Microsemi
# switch and PHY products.  The source code of the software may not be
# disclosed, transmitted or distributed without the prior written permission of
# Microsemi.
#
# This copyright notice must appear in any copy, modification, disclosure,
# transmission or distribution of the software.  Microsemi retains all
# ownership, copyright, trade secret and proprietary rights in the software and
# its source code, including all modifications thereto.
#
# THIS SOFTWARE HAS BEEN PROVIDED "AS IS". MICROSEMI HEREBY DISCLAIMS ALL
# WARRANTIES OF ANY KIND WITH RESPECT TO THE SOFTWARE, WHETHER SUCH WARRANTIES
# ARE EXPRESS, IMPLIED, STATUTORY OR OTHERWISE INCLUDING, WITHOUT LIMITATION,
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR USE OR PURPOSE AND
# NON-INFRINGEMENT.

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
  "linstax" => "WebStax-Release",
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
