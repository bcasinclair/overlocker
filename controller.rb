# This one takes the original requests 
# does the inspection and hands the segment encodes out to the workers then
# Gets the notifications back and does the stitching

require 'sinatra'
#require 'json'
#require 'base64'
##require 'httpclient'
require 'openssl'

set :bind, '0.0.0.0'
set :port, 9494

require_relative 'downloader'

get '/hi' do
  "Hellow world"
end 

get '/file/:file' do
  send_file File.join(File.join("source/",params[:file]))
end

get '/process/:file' do
	d = Downloader.new(File.join(File.join("source/",params[:file])))
	d.process_file(File.join(File.join("source/",params[:file])))
end

get '/register/:address' do
	puts "#{params[:address]}"
	return "#{params[:address]}"
end