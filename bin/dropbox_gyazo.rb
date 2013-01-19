#!/usr/bin/env ruby

require 'fileutils'
require 'digest/md5'
require 'open-uri'

file = File.expand_path "~/Dropbox/Public/screenshot/#{Digest::MD5.hexdigest(Time.now.to_f.to_s)}.png"
url = 'http://dl.dropbox.com/u/6826498/screenshot/' + File.basename(file)

FileUtils.mkdir_p File.dirname(file)

system "screencapture -i \"#{file}\""
if File.exist?(file) then
  system "sips -d profile --deleteColorManagementProperties \"#{file}\""
end

begin
  open(url)
rescue
  sleep 0.3
  retry
end

system "echo -n #{url} | pbcopy"
system "open #{url}"
