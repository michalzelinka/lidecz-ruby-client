#!/usr/bin/env ruby

require 'net/https'
require 'fileutils'
require 'pp'
load 'lide.rb'

if ARGV.count == 0 then
	puts "Usage: #{$0} profile1 [profile2 profile3 ...]"
	exit
end

FileUtils.mkdir('img_dl') if !File.exists? 'img_dl'

ARGV.each{|profile|

	profileFolder = `ls | grep #{profile}`.strip
	profileFolder = profile if profileFolder.length == 0
	profileFolder = 'img_dl/' + profileFolder

	imgs = [ ]

	d = LideAPI.request('profile.get', [profile])
	d = d['data']['profile'] if d
	imgs.push d['photo']['url'] if d

	lastPhotoID = nil
	0.upto(100){|loopy|
		pagesize = 20
		d = LideAPI.request('profile.get.photos', [profile, lastPhotoID, pagesize])
		d = d['data']['gallery']
		break if d == nil
		d.each {|p| imgs.push p['url'] }
		lastPhotoID = d[-1]['id'] if d.count > 0
		break if d.count < pagesize
	}

	if imgs.count then
		FileUtils.mkdir(profileFolder) if !File.exists? profileFolder
	end

	imgs.each{|u|
		next if u == nil
		u = 'https:'+u if u.index('//') == 0
		fn = u[u.rindex('/')+1..-1]
		fpath = profileFolder+'/'+fn
		next if File.exists? fpath
		data = Net::HTTP.get(URI(u))
		next if data == nil
		File.open(fpath, 'w'){|f| f << data }
	}

}
